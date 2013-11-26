--Created by: Jeffrey Meyers
--Contact: jeffrey dot alan dot meyers at gmail dot com
--For: TriMet
--Created on: November 2013
--Updated on: November 2013

/*
This sql script creates a diff table showing differences in geometry between osm and jurisdictional data.
The expected schema of the jurisdictional data for this script is what rlis_streets2osm.sql produces.

Column Names:
  geom
  oneway
  direction
  name
  description
  highway
  access
  service
  surface
  pc_left
  pc_right


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

DROP TABLE IF EXISTS osm_buffer;
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

DROP TABLE IF EXISTS grid;
CREATE TABLE grid AS
(
  SELECT (ST_Dump(st_collect)).geom AS geom
    FROM initial_grid
);

DROP VIEW initial_grid;
DROP VIEW extents;

UPDATE grid SET geom = ST_SetSRID(geom, 2913);
CREATE SEQUENCE grid_seq;
ALTER TABLE grid ADD grid_id int;
UPDATE grid SET grid_id = nextval('grid_seq');
DROP SEQUENCE grid_seq;
CREATE INDEX ON grid USING gist(geom);

DROP TABLE IF EXISTS buffer_box;
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

CREATE TABLE jurisd_dissolve AS
(
  SELECT sq.oneway,
         sq.direction,
         sq.name,
         sq.description,
         sq.highway,
         sq.access,
         sq.service,
         sq.surface,
         sq.pc_left,
         sq.pc_right,
         (ST_Dump(sq.geom)).geom AS geom
    FROM 
    (
      SELECT jurisd.oneway,
             jurisd.direction,
             jurisd.name,
             jurisd.description,
             jurisd.highway,
             jurisd.access,
             jurisd.service,
             jurisd.surface,
             jurisd.pc_left,
             jurisd.pc_right,
             ST_LineMerge(ST_Union(jurisd.geom)) AS geom
        FROM :jurisd AS jurisd
        GROUP BY jurisd.oneway,
                 jurisd.direction,
                 jurisd.name,
                 jurisd.description,
                 jurisd.highway,
                 jurisd.access,
                 jurisd.service,
                 jurisd.surface,
                 jurisd.pc_left,
                 jurisd.pc_right
    ) AS sq
);

CREATE SEQUENCE jurisd_seq;
ALTER TABLE jurisd_dissolve ADD gid int;
UPDATE jurisd_dissolve SET gid = nextval('jurisd_seq');
DROP SEQUENCE jurisd_seq;
CREATE INDEX ON jurisd_dissolve USING gist(geom);

DROP TABLE IF EXISTS jurisd_box;
CREATE TABLE jurisd_box AS
(
  SELECT grid.grid_id,
         jurisd.gid,
         jurisd.oneway,
         jurisd.direction,
         jurisd.name,
         jurisd.description,
         jurisd.highway,
         jurisd.access,
         jurisd.service,
         jurisd.surface,
         jurisd.pc_left,
         jurisd.pc_right,
         ST_Intersection(grid.geom, jurisd.geom) AS geom
    FROM grid, jurisd_dissolve AS jurisd
    WHERE ST_Intersects(grid.geom, jurisd.geom)
);

DROP TABLE jurisd_dissolve;
CREATE INDEX ON jurisd_box USING btree(grid_id);
CREATE INDEX ON jurisd_box USING gist(geom);

CREATE VIEW initial_diff AS
(
  SELECT jurisd.gid,
         jurisd.oneway,
         jurisd.direction,
         jurisd.name,
         jurisd.description,
         jurisd.highway,
         jurisd.access,
         jurisd.service,
         jurisd.surface,
         jurisd.pc_left,
         jurisd.pc_right,
         ST_Difference(jurisd.geom, buffer.geom) AS geom
    FROM jurisd_box AS jurisd, buffer_box AS buffer
    WHERE jurisd.grid_id = buffer.grid_id
  UNION
  SELECT jurisd.gid,
         jurisd.oneway,
         jurisd.direction,
         jurisd.name,
         jurisd.description,
         jurisd.highway,
         jurisd.access,
         jurisd.service,
         jurisd.surface,
         jurisd.pc_left,
         jurisd.pc_right,
         jurisd.geom
    FROM jurisd_box AS jurisd
    WHERE jurisd.grid_id NOT IN (SELECT grid_id FROM buffer_box)
);

DROP TABLE IF EXISTS :diff;
CREATE TABLE :diff AS
(
  SELECT jurisd.oneway,
         jurisd.direction,
         jurisd.name,
         jurisd.description,
         jurisd.highway,
         jurisd.access,
         jurisd.service,
         jurisd.surface,
         jurisd.pc_left,
         jurisd.pc_right,
         ST_Union(jurisd.geom) AS geom
    FROM initial_diff as jurisd
    GROUP BY jurisd.oneway,
             jurisd.direction,
             jurisd.name,
             jurisd.description,
             jurisd.highway,
             jurisd.access,
             jurisd.service,
             jurisd.surface,
             jurisd.pc_left,
             jurisd.pc_right
);

ALTER TABLE :diff ADD length real;
UPDATE :diff SET length = ST_Length(geom);
DELETE FROM :diff WHERE length < 50;

DROP VIEW initial_diff;

COMMIT;
