
--Works except performance is terrible with the entire road network buffer gets is merged into one polygon
/*
CREATE TABLE diff AS
(
   SELECT salem.*, ST_Difference(salem.geom, buffer.geom) AS new_geom
   FROM 
      salem_osm_sts AS salem, (SELECT (ST_Dump(merge_buffer.geom)).geom AS geom
                               FROM (SELECT ST_Union(ST_Buffer(osm.way, 30)) AS geom
                                     FROM planet_osm_line AS osm) AS merge_buffer) AS buffer
   WHERE ST_Intersects(salem.geom, buffer.geom)
); 

CREATE TABLE contain AS
(
   SELECT salem.*
   FROM salem_osm_sts, (SELECT ST_Buffer(osm.way) AS geom
                        FROM planet_osm_line AS osm) AS buffer
   WHERE ST_Contains(buffer.geom, salem.geom)
);


*/
DROP TABLE IF EXISTS contain;




CREATE TABLE contain AS
(
   SELECT test_line.*
   FROM test_line, test_poly
   WHERE ST_Contains(test_poly.geom, test_line.geom)
);