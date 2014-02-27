--Created by: Jeffrey Meyers
--Contact: jeffrey dot alan dot meyers at gmail dot com
--For: TriMet
--Created on: November 2013
--Updated on: November 2013


BEGIN;

DROP TABLE IF EXISTS osm_buffer;
DROP TABLE IF EXISTS grid;
DROP TABLE IF EXISTS buffer_box;
DROP TABLE IF EXISTS jurisd_box;
DROP TABLE IF EXISTS :diff;

--**********************************************************************************
--function to create fishnet
--source: http://trac.osgeo.org/postgis/wiki/UsersWikiCreateFishnet
CREATE OR REPLACE FUNCTION ST_CreateFishnet(
        nrow integer, ncol integer,
                xsize float8, ysize float8,
                        x0 float8 DEFAULT 0, y0 float8 DEFAULT 0,
                                OUT "row" integer, OUT col integer,
                                        OUT geom geometry)
    RETURNS SETOF record AS
    $$
    SELECT i + 1 AS row, j + 1 AS col, ST_Translate(cell, j * $3 + $5, i * $4 + $6) AS geom
    FROM generate_series(0, $1 - 1) AS i,
         generate_series(0, $2 - 1) AS j,
         (
         SELECT ('POLYGON((0 0, 0 '||$4||', '||$3||' '||$4||', '||$3||' 0,0 0))')::geometry AS cell
         ) AS foo;
         $$ LANGUAGE sql IMMUTABLE STRICT;
--**********************************************************************************


--example usage

--psql -U postgres -d db_name -v osm=osm_table -v jurisd=jurisid_data_table -v diff=output_table -f process_diff.sql

--Create buffer on osm file passed in as argument
CREATE TABLE osm_buffer AS
(
  SELECT ST_Buffer(osm.geom, 30) AS geom
  FROM :osm AS osm
);

CREATE INDEX ON osm_buffer USING gist(geom);

--create view with extents of osm_buffer
CREATE VIEW extents AS
(
  SELECT ST_Xmin(ST_Extent(geom)) AS x_orig, 
         ST_Ymin(ST_Extent(geom)) AS y_orig,
         ST_Xmax(ST_Extent(geom)) AS x_max,
         ST_Ymax(ST_Extent(geom)) AS y_max 
    FROM osm_buffer
);


--build fishnet using extent of osm_buffer with cell sizes of 1320(map units)
CREATE VIEW initial_grid AS 
(
  SELECT ST_Collect(cells.geom)
  FROM ST_CreateFishnet(
    cast((SELECT ceiling(((y_max - y_orig) / 1320)) FROM extents) AS int),
    cast((SELECT ceiling(((x_max - x_orig) / 1320)) FROM extents) AS int),
    1320,
    1320,
    (SELECT x_orig FROM extents),
    (SELECT y_orig FROM extents)) AS cells
);

--create different feature for each cell in fishnet
CREATE TABLE grid AS
(
  SELECT (ST_Dump(st_collect)).geom AS geom
    FROM initial_grid
);

DROP VIEW initial_grid;
DROP VIEW extents;

--set projection of grid
UPDATE grid SET geom = ST_SetSRID(geom, 2913);

--create unique grid_id for each cell
CREATE SEQUENCE grid_seq;
ALTER TABLE grid ADD grid_id int;
UPDATE grid SET grid_id = nextval('grid_seq');
DROP SEQUENCE grid_seq;
CREATE INDEX ON grid USING gist(geom);

--intersect osm_buffer with grid and dissolve buffers in each cell
CREATE TABLE buffer_box AS
(
  SELECT grid.grid_id,
         ST_Union(ST_Intersection(grid.geom, buffer.geom)) AS geom
    FROM grid, osm_buffer AS buffer
    WHERE ST_Intersects(grid.geom, buffer.geom)
    GROUP BY grid.grid_id
);

CREATE INDEX ON buffer_box USING btree(grid_id);
CREATE INDEX ON buffer_box USING gist(geom);


--TODO this query doesn't work right.
--more features are dissolved than should be even if they don't touch

--dissolve jurisidctional data by attributes and merge only touching line segments
CREATE TABLE jurisd_dissolve AS
(
  SELECT sq.prefix,
         sq.streetname,
         sq.ftype,
         (ST_Dump(sq.geom)).geom AS geom
    FROM 
    (
      SELECT jurisd.prefix,
             jurisd.streetname,
             jurisd.ftype,
             ST_LineMerge(ST_Union(jurisd.geom)) AS geom
        FROM :jurisd AS jurisd
        GROUP BY jurisd.prefix,
                 jurisd.streetname,
                 jurisd.ftype
    ) AS sq
);


--create unique id on intersecting jurisdictional data
CREATE SEQUENCE jurisd_seq;
ALTER TABLE jurisd_dissolve ADD gid int;
UPDATE jurisd_dissolve SET gid = nextval('jurisd_seq');
DROP SEQUENCE jurisd_seq;
CREATE INDEX ON jurisd_dissolve USING gist(geom);


--intersect dissolved jurisdictional data with grid
CREATE TABLE jurisd_box AS
(
  SELECT jurisd.gid,
         jurisd.prefix,
         jurisd.streetname,
         jurisd.ftype,
         grid.grid_id,
         ST_Intersection(grid.geom, jurisd.geom) AS geom
    FROM grid, jurisd_dissolve AS jurisd
    WHERE ST_Intersects(grid.geom, jurisd.geom)
);

DROP TABLE jurisd_dissolve;
CREATE INDEX ON jurisd_box USING btree(grid_id);
CREATE INDEX ON jurisd_box USING gist(geom);


--where gridded buffer and gridded jurisdictional data have same grid id take difference
--if jurisdictional data grid_id is not in the gridded buffer select it as well
CREATE VIEW initial_diff AS
(
  SELECT jurisd.gid,
         jurisd.prefix,
         jurisd.streetname,
         jurisd.ftype,
         ST_Difference(jurisd.geom, buffer.geom) AS geom
    FROM jurisd_box AS jurisd, buffer_box AS buffer
    WHERE jurisd.grid_id = buffer.grid_id
  UNION
  SELECT jurisd.gid,
         jurisd.prefix,
         jurisd.streetname,
         jurisd.ftype,
         jurisd.geom
    FROM jurisd_box AS jurisd
    WHERE jurisd.grid_id NOT IN (SELECT grid_id FROM buffer_box)
);


--TODO this query may need to be corrected as well
--output is not what is expected

--create final table same intial streets together
CREATE TABLE :diff AS
(
  SELECT jurisd.gid,
         jurisd.prefix,
         jurisd.streetname,
         jurisd.ftype,
         ST_Union(jurisd.geom) AS geom
    FROM initial_diff as jurisd
    GROUP BY jurisd.gid, jurisd.prefix, jurisd.streetname, jurisd.ftype
);

--delete any segments shorter than 50 ft
ALTER TABLE :diff ADD length real;
UPDATE :diff SET length = ST_Length(geom);
DELETE FROM :diff WHERE length < 50;

DROP VIEW initial_diff;

COMMIT;
