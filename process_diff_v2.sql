BEGIN;

/*
CREATE VIEW osm_buffer AS
(
   SELECT ST_Buffer(planet_osm_line.way, 30) AS geom
   FROM planet_osm_line
);


TODO

  -create a vector grid used to partition the unionized buffer
  -break up buffer into smaller polygons using square partitions
  -build index on partitioned buffers
  -run ST_Difference with joining on ST_Intersects
  -union with join on ST_Disjoint



--CREATE VIEW osm_buffer_dump AS
--(
--   SELECT (ST_Dump(osm_buffer_union.geom)).geom AS geom
--   FROM osm_buffer_union
--);
--*/

DROP VIEW IF EXISTS grid_intersection;
DROP VIEW IF EXISTS osm_buffer_union;

CREATE VIEW osm_buffer_union AS
(
   SELECT ST_Union(osm.geom) AS geom
   FROM osm_sts_test_buffer AS osm
);

CREATE VIEW grid_intersection AS
(
   SELECT ST_Intersection(buffer.geom, grid.geom) AS geom
   FROM grid_1000ft AS grid, osm_buffer_union AS buffer
   WHERE ST_Intersects(grid.geom, buffer.geom) 
);


/*
CREATE TABLE salem_diff AS
(
   SELECT salem_osm_sts.*, ST_Difference(salem_osm_sts.geom, osm_buffer_dump.geom) AS new_geom
   FROM salem_osm_sts, osm_buffer_dump
   WHERE salem_osm_sts.gid NOT IN (SELECT salem_osm_sts.gid
                                   FROM salem_osm_sts, osm_buffer
								   WHERE ST_Contains(osm_buffer.geom, salem_osm_sts.geom))
   AND ST_Intersects(salem_osm_sts.geom, osm_buffer_dump.geom)
   UNION
   SELECT salem_osm_sts.*, salem_osm_sts.geom AS new_geom
   FROM salem_osm_sts
   WHERE salem_osm_sts.gid NOT IN (SELECT salem_osm_sts.gid
                                   FROM salem_osm_sts, osm_buffer
							       WHERE ST_Intersects(salem_osm_sts.geom, osm_buffer.geom))
);
*/


 
--DROP VIEW osm_buffer;
--DROP VIEW osm_buffer_union;
--DROP VIEW osm_buffer_dump;

COMMIT;


