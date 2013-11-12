BEGIN;

/*
CREATE VIEW osm_buffer AS
(
   SELECT ST_Buffer(planet_osm_line.way, 30) AS geom
   FROM planet_osm_line
);

CREATE VIEW osm_buffer_union AS
(
   SELECT ST_Union(osm_buffer.geom) AS geom
   FROM osm_buffer
);

CREATE VIEW osm_buffer_dump AS
(
   SELECT (ST_Dump(osm_buffer_union.geom)).geom AS geom
   FROM osm_buffer_union
);
*/

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
   
--DROP VIEW osm_buffer;
--DROP VIEW osm_buffer_union;
--DROP VIEW osm_buffer_dump;

COMMIT;


