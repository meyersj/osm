BEGIN;

CREATE TABLE rlis_streets_diff_mult AS
(
  SELECT rlis.*
  FROM rlis_streets_diff AS rlis
  JOIN co_fill AS co
  ON ST_Intersects(rlis.geom, co.geom)
  WHERE co.county = 'Multnomah'
);

CREATE TABLE rlis_streets_diff_wash AS
(
  SELECT rlis.*
  FROM rlis_streets_diff AS rlis
  JOIN co_fill AS co
  ON ST_Intersects(rlis.geom, co.geom)
  WHERE co.county = 'Washington'
);

CREATE TABLE rlis_streets_diff_clack AS
(
  SELECT rlis.*
  FROM rlis_streets_diff AS rlis
  JOIN co_fill AS co
  ON ST_Intersects(rlis.geom, co.geom)
  WHERE co.county = 'Clackamas'
);

CREATE TABLE rlis_streets_diff_yam AS
(
  SELECT rlis.*
  FROM rlis_streets_diff AS rlis
  JOIN co_fill AS co
  ON ST_Intersects(rlis.geom, co.geom)
  WHERE co.county = 'Yamhill'
);

COMMIT;
