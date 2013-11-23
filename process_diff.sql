BEGIN;

DROP TABLE IF EXISTS osm_test_buffer;
DROP TABLE IF EXISTS grid;
DROP TABLE IF EXISTS test_buffer_box;
DROP TABLE IF EXISTS test_rlis_box;
DROP TABLE IF EXISTS test_diff;


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

CREATE TABLE osm_test_buffer AS
(
  SELECT ST_Buffer(osm.geom, 30) AS geom
  FROM osm_sts_test AS osm
);

CREATE INDEX ON osm_test_buffer using gist(geom);

CREATE VIEW extents AS
(
  SELECT ST_Xmin(ST_Extent(geom)) AS x_orig, 
         ST_Ymin(ST_Extent(geom)) AS y_orig,
         ST_Xmax(ST_Extent(geom)) AS x_max,
         ST_Ymax(ST_Extent(geom)) AS y_max 
    FROM osm_test_buffer
);

CREATE VIEW test_grid AS 
(
  SELECT ST_Collect(cells.geom)
  FROM ST_CreateFishnet(
    cast((SELECT ceiling(((y_max - y_orig) / 250)) FROM extents) AS int),
    cast((SELECT ceiling(((x_max - x_orig) / 250)) FROM extents) AS int),
    250,
    250,
    (SELECT x_orig FROM extents),
    (SELECT y_orig FROM extents)) AS cells
);

CREATE TABLE grid AS
(
  SELECT (ST_Dump(st_collect)).geom AS geom
    FROM test_grid
);

DROP VIEW test_grid;
DROP VIEW extents;

UPDATE grid SET geom = ST_SetSRID(geom, 2913);
CREATE SEQUENCE grid_seq;
ALTER TABLE grid ADD grid_id int;
UPDATE grid SET grid_id = nextval('grid_seq');
DROP SEQUENCE grid_seq;


CREATE TABLE test_buffer_box AS
(
  SELECT grid.grid_id,
         ST_Union(ST_Intersection(grid.geom, buffer.geom)) AS geom
    FROM grid, osm_test_buffer AS buffer
    WHERE ST_Intersects(grid.geom, buffer.geom)
    GROUP BY grid.grid_id
);

CREATE INDEX ON test_buffer_box USING gist(geom);

CREATE TABLE test_rlis_box AS
(
  SELECT rlis.gid,
         rlis.prefix,
         rlis.streetname,
         rlis.ftype,
         grid.grid_id,
         ST_Intersection(grid.geom, rlis.geom) AS geom
    FROM grid, rlis_sts_test AS rlis
    WHERE ST_Intersects(grid.geom, rlis.geom)
);

CREATE INDEX ON test_rlis_box USING gist(geom);

CREATE VIEW diff AS
(
  SELECT rlis.gid,
         rlis.prefix,
         rlis.streetname,
         rlis.ftype,
         ST_Difference(rlis.geom, buffer.geom) AS geom
    FROM test_rlis_box AS rlis, test_buffer_box AS buffer
    WHERE rlis.grid_id = buffer.grid_id
  UNION
  SELECT rlis.gid,
         rlis.prefix,
         rlis.streetname,
         rlis.ftype,
         rlis.geom
    FROM test_rlis_box AS rlis
    WHERE rlis.grid_id NOT IN (SELECT grid_id FROM test_buffer_box)
);

CREATE TABLE test_diff AS
(
  SELECT rlis.gid,
         rlis.prefix,
         rlis.streetname,
         rlis.ftype,
         ST_Union(rlis.geom) AS geom
    FROM diff as rlis
    GROUP BY rlis.gid, rlis.prefix, rlis.streetname, rlis.ftype
);

DROP VIEW diff;

COMMIT;
