--Created By: Jeffrey Meyers
--Contact: jeffrey dot alan dot meyers at gmail dot com
--For: TriMet
--Created: November 2013
--Updated: October 2013

--script assumes rlis bike table is named 'rlis_bike'
--script creates table with converted attributes named 'rlis_osm_bike'

BEGIN;

--1) create table based on RLIS rlis_bike columns
DROP TABLE IF EXISTS rlis_osm_bike;
CREATE TABLE rlis_osm_bike 
(
    id serial PRIMARY KEY,
    gid int REFERENCES rlis_bike,
    geom geometry,
	prefix text,
	streetname text,
	ftype text,
	bikemode text,
    name text, --osm tag derived from prefix + streetname + ftype
    highway text, --osm tag to identify proposed bike infrastructure
	proposed text, --osm tag used for proposed bike infrastructure
	bicycle text, --will be osm conversion from bikemode
	cycleway text, --will be osm conversion from bikemode
    "RLIS:bicycle" text --used for bikemode == Caution area

);

--2) update salem_osm_sts with ctrline columns
INSERT INTO rlis_osm_bike (gid, geom, prefix, streetname, ftype, bikemode)
(
    SELECT rlis.gid, 
	       rlis.geom,
           rlis.prefix,
           rlis.streetname,
           rlis.ftype,
           rlis.bikemode
    FROM rlis_bike AS rlis
);

--3) prefix expansion
UPDATE rlis_osm_bike SET prefix = 'Northwest'
   WHERE prefix = 'NW';
UPDATE rlis_osm_bike set prefix = 'Southwest'
   WHERE prefix = 'SW';
UPDATE rlis_osm_bike set prefix = 'Southeast'
   WHERE prefix = 'SE';
UPDATE rlis_osm_bike set prefix = 'Northeast'
   WHERE prefix = 'NE';
UPDATE rlis_osm_bike set prefix = 'North'
   WHERE prefix = 'N';
UPDATE rlis_osm_bike set prefix = 'East'
   WHERE prefix = 'E';
UPDATE rlis_osm_bike set prefix = 'South'
   WHERE prefix = 'S';
UPDATE rlis_osm_bike set prefix = 'West'
   WHERE prefix = 'W';
   
--4) ftype expansion
UPDATE rlis_osm_bike set ftype = 'Alley' WHERE ftype = 'Aly';
UPDATE rlis_osm_bike set ftype = 'Avenue' WHERE ftype = 'Ave';
UPDATE rlis_osm_bike set ftype = 'Boulevard' WHERE ftype = 'Blvd';
UPDATE rlis_osm_bike set ftype = 'Bridge' WHERE ftype = 'Brg';
UPDATE rlis_osm_bike set ftype = 'Circle' WHERE ftype = 'Cir';
UPDATE rlis_osm_bike set ftype = 'Connection' WHERE ftype = 'Cnct';
UPDATE rlis_osm_bike set ftype = 'Corridor' WHERE ftype = 'Corr';
UPDATE rlis_osm_bike set ftype = 'Crescent' WHERE ftype = 'Crst';
UPDATE rlis_osm_bike set ftype = 'Court' WHERE ftype = 'Ct';
UPDATE rlis_osm_bike set ftype = 'Drive' WHERE ftype = 'Dr';
UPDATE rlis_osm_bike set ftype = 'Expressway' WHERE ftype = 'Expy';
UPDATE rlis_osm_bike set ftype = 'Frontage' WHERE ftype = 'Frtg';
UPDATE rlis_osm_bike set ftype = 'Freeway' WHERE ftype = 'Fwy';
UPDATE rlis_osm_bike set ftype = 'Highway' WHERE ftype = 'Hwy';
UPDATE rlis_osm_bike set ftype = 'Lane' WHERE ftype = 'Ln';
UPDATE rlis_osm_bike set ftype = 'Landing' WHERE ftype = 'Lndg';
UPDATE rlis_osm_bike set ftype = 'Loop' WHERE ftype = 'Loop';
UPDATE rlis_osm_bike set ftype = 'Park' WHERE ftype = 'Park';
UPDATE rlis_osm_bike set ftype = 'Path' WHERE ftype = 'Path';
UPDATE rlis_osm_bike set ftype = 'Parkway' WHERE ftype = 'Pkwy';
UPDATE rlis_osm_bike set ftype = 'Place' WHERE ftype = 'Pl';
UPDATE rlis_osm_bike set ftype = 'Point' WHERE ftype = 'Pt';
UPDATE rlis_osm_bike set ftype = 'Ramp' WHERE ftype = 'Ramp';
UPDATE rlis_osm_bike set ftype = 'Road' WHERE ftype = 'Rd';
UPDATE rlis_osm_bike set ftype = 'Ridge' WHERE ftype = 'Rdg';
UPDATE rlis_osm_bike set ftype = 'Railroad' WHERE ftype = 'RR';
UPDATE rlis_osm_bike set ftype = 'Row' WHERE ftype = 'Row';
UPDATE rlis_osm_bike set ftype = 'Run' WHERE ftype = 'Run';
UPDATE rlis_osm_bike set ftype = 'Spur' WHERE ftype = 'Spur';
UPDATE rlis_osm_bike set ftype = 'Square' WHERE ftype = 'Sq';
UPDATE rlis_osm_bike set ftype = 'Street' WHERE ftype = 'St';
UPDATE rlis_osm_bike set ftype = 'Terrace' WHERE ftype = 'Ter';
UPDATE rlis_osm_bike set ftype = 'Trail' WHERE ftype = 'Trl';
UPDATE rlis_osm_bike set ftype = 'Trail' WHERE ftype = 'Trlt';
UPDATE rlis_osm_bike set ftype = 'View' WHERE ftype = 'Vw';
UPDATE rlis_osm_bike set ftype = 'Walk' WHERE ftype = 'Walk';
UPDATE rlis_osm_bike set ftype = 'Way' WHERE ftype = 'Way';

--6) concatenate prefix, streetname, ftype and insert into name
UPDATE rlis_osm_bike 
   SET name = subquery.name
   FROM 
   (       
       SELECT gid, TRIM(CONCAT_WS(' ', COALESCE(prefix, ''),
                                       COALESCE(streetname, ''),
                                       COALESCE(ftype, ''))) AS name
       FROM rlis_osm_bike
   ) AS subquery
   WHERE rlis_osm_bike.gid = subquery.gid;


--7) update bicycle infrastructure tags using bikemode attribute
UPDATE rlis_osm_bike 
   SET bicycle = 'designated'
   WHERE bikemode IN ('Low traffic through street',
                      'Regional multi-use path',
                      'Local multi-use path',
                      'High traffic through street',
                      'Moderate traffic through street');

UPDATE rlis_osm_bike 
   SET bicycle = 'designated', cycleway = 'shared_lane'
   WHERE bikemode = 'Bike boulevard';

UPDATE rlis_osm_bike 
   SET bicycle = 'designated', cycleway = 'lane'
   WHERE bikemode = 'Bike lane';

UPDATE rlis_osm_bike 
   SET "RLIS:bicycle" = 'caution_area'
   WHERE bikemode = 'Caution area';

UPDATE rlis_osm_bike 
   SET "RLIS:bicycle" = 'caution_area'
   WHERE bikemode = 'Caution area';

UPDATE rlis_osm_bike 
   SET highway = 'proposed', proposed = 'path'
   WHERE bikemode = 'Planned multi-use path';

UPDATE rlis_osm_bike 
   SET cycleway = 'proposed', proposed = 'lane'
   WHERE bikemode = 'Planned multi-use path';

COMMIT;
