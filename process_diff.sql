BEGIN;

DROP TABLE IF EXISTS osm_test_buffer;
DROP TABLE IF EXISTS test_disjoint; 
DROP TABLE IF EXISTS test_difference;
DROP TABLE IF EXISTS test_final;

CREATE TABLE osm_test_buffer AS
(
  SELECT ST_Union(ST_Buffer(osm.geom, 30)) AS geom
  FROM osm_sts_test AS osm
);

CREATE TABLE test_disjoint AS
(
  SELECT rlis.prefix, 
         rlis.streetname, 
         rlis.ftype,
         rlis.geom 
  FROM rlis_sts_test AS rlis, osm_test_buffer AS osm
  WHERE ST_Disjoint(rlis.geom, osm.geom)
);

CREATE TABLE test_difference AS
(
  SELECT rlis.prefix, 
         rlis.streetname, 
         rlis.ftype,
         ST_Difference(rlis.geom, osm.geom) AS geom
  FROM rlis_sts_test AS rlis, osm_test_buffer AS osm
  WHERE ST_Intersects(rlis.geom, osm.geom)
);

ALTER TABLE test_difference ADD length real;

UPDATE test_difference
SET length = ST_Length(test_difference.geom);

DELETE FROM test_difference
WHERE length < 50;

CREATE TABLE test_final AS
(
  SELECT st.prefix,
         st.streetname,
         st.ftype,
         st.geom
  FROM test_disjoint AS st
  UNION
  SELECT st.prefix,
         st.streetname,
         st.ftype,
         st.geom
  FROM test_difference AS st
);

COMMIT;
