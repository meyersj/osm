--Created by: Jeffrey Meyers
--Contact: jeffrey dot alan dot meyers at gmail dot com
--For: TriMet
--Created on: November 2013
--Updated on: Jan 2014

/*
This sql template creates a diff table showing differences in geometry between osm and jurisdictional data.

This template needs to be used as input into build_sql.py in order to fill in the attributes that are relevant
for specific jurisdicional set being used before in can be run as an sql file.

This script expects three arguments to be passed when running it.
  osm=osm data (osm data filtered for highways)
  jurisd=jurisdictional data (rlis streets)
  buf_size = name of table used to increase buffer size in rural areas
  diff=name of output table

Example Usage:
  psql -U postgres -d dbname -v osm=osm_table -v jurisd=rlis_table -v buf_size=urban_buffers -v diff=rlis_diff -f generate_diff_rlis_streets.sql
*/

BEGIN;
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

CREATE TABLE osm_buffer AS
(
  SELECT ST_Buffer(sq.geom, sq.buf_size) AS geom
    FROM
    (
      SELECT ub.buffer AS buf_size,
             ST_Intersection(ub.geom, osm.geom) AS geom
        FROM :buf_size AS ub, :osm AS osm
        WHERE ST_Intersects(ub.geom, osm.geom)
    ) AS sq
);

CREATE INDEX ON osm_buffer using gist(geom);

CREATE VIEW extents AS
(
  SELECT ST_Xmin(ST_Extent(geom)) AS x_orig, 
         ST_Ymin(ST_Extent(geom)) AS y_orig,
         ST_Xmax(ST_Extent(geom)) AS x_max,
         ST_Ymax(ST_Extent(geom)) AS y_max 
    FROM osm_buffer
);

CREATE TABLE grid  
(
  grid_id serial primary key,
  geom geometry
);

INSERT INTO grid (geom)
(
  SELECT cells.geom
  FROM ST_CreateFishnet(
    cast((SELECT ceiling(((y_max - y_orig) / 1320)) FROM extents) AS int),
    cast((SELECT ceiling(((x_max - x_orig) / 1320)) FROM extents) AS int),
    1320,
    1320,
    (SELECT x_orig FROM extents),
    (SELECT y_orig FROM extents)) AS cells
);

UPDATE grid SET geom = ST_SetSRID(geom, 2913);
CREATE INDEX ON grid USING gist(geom);
DROP VIEW extents;

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

CREATE TABLE jurisd_box AS
(
  SELECT {{jurisd}}
         grid.grid_id,
         jurisd.gid,
         ST_Intersection(grid.geom, jurisd.geom) AS geom
    FROM grid, :jurisd AS jurisd
    WHERE ST_Intersects(grid.geom, jurisd.geom)
);

CREATE INDEX ON jurisd_box USING btree(grid_id);
CREATE INDEX ON jurisd_box USING gist(geom);

CREATE VIEW initial_diff AS
(
  SELECT {{jurisd}}
         jurisd.gid,
         ST_Difference(jurisd.geom, buffer.geom) AS geom
    FROM jurisd_box AS jurisd, buffer_box AS buffer
    WHERE jurisd.grid_id = buffer.grid_id
  UNION
  SELECT {{jurisd}}
         jurisd.gid,         
         jurisd.geom
    FROM jurisd_box AS jurisd
    WHERE jurisd.grid_id NOT IN (SELECT grid_id FROM buffer_box)
);


DROP TABLE IF EXISTS :diff;
CREATE TABLE :diff AS
(
  SELECT {{sq}}
         (ST_Dump(sq.geom)).geom AS geom
    FROM 
    (
      SELECT {{diff}}
             ST_LineMerge(ST_Union(diff.geom)) AS geom
        FROM initial_diff AS diff
        GROUP BY {{diff_end}}
    ) AS sq
);

ALTER TABLE :diff ADD length real;
UPDATE :diff SET length = ST_Length(geom);
DELETE FROM :diff WHERE length < 50;

DROP VIEW initial_diff;
DROP TABLE grid;
DROP TABLE buffer_box;
DROP TABLE jurisd_box;
DROP TABLE osm_buffer;

COMMIT;
