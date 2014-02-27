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

--CREATE TABLE fpos_union AS
--(
--  SELECT ST_Union(geom) AS geom
--  FROM false_positive
--);


DROP TABLE IF EXISTS :fpos_final;

CREATE VIEW extents AS
(
  SELECT ST_Xmin(ST_Extent(geom)) AS x_orig, 
         ST_Ymin(ST_Extent(geom)) AS y_orig,
         ST_Xmax(ST_Extent(geom)) AS x_max,
         ST_Ymax(ST_Extent(geom)) AS y_max 
    FROM :jurisd
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

-- grid false_positive file and union based on grid location
CREATE TABLE fpos_box AS
(
  SELECT grid.grid_id,
         ST_Union(ST_Intersection(grid.geom, ST_Buffer(fpos.geom, 0.5))) AS geom
    FROM grid
    JOIN :fpos AS fpos
    ON ST_Intersects(grid.geom, fpos.geom)
    GROUP BY grid.grid_id
);

CREATE INDEX ON fpos_box USING btree(grid_id);
CREATE INDEX ON fpos_box USING gist(geom);

-- grid jurisdictional data
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

CREATE TABLE temp_fpos_rm AS
(
  SELECT {{jurisd}}
         jurisd.gid,
         ST_Difference(jurisd.geom, fpos.geom) AS geom
    FROM jurisd_box AS jurisd, fpos_box AS fpos
    WHERE jurisd.grid_id = fpos.grid_id
  UNION
  SELECT {{jurisd}}
         jurisd.gid,
         jurisd.geom
    FROM jurisd_box AS jurisd, fpos_box AS fpos
    WHERE jurisd.grid_id = fpos.grid_id AND
          ST_Disjoint(jurisd.geom, fpos.geom)
  UNION
  SELECT {{jurisd}}
         jurisd.gid,
         jurisd.geom
    FROM jurisd_box AS jurisd
    WHERE jurisd.grid_id NOT IN (SELECT grid_id FROM fpos_box)
);

CREATE TABLE :fpos_final AS
(
  SELECT {{jurisd}}
         jurisd.gid,
         ST_Union(jurisd.geom) AS geom
    FROM temp_fpos_rm AS jurisd
    GROUP BY {{jurisd}}jurisd.gid
);

DROP TABLE IF EXISTS grid;
DROP TABLE IF EXISTS fpos_box;
DROP TABLE IF EXISTS jurisd_box;
DROP TABLE IF EXISTS temp_fpos_rm;

COMMIT;
