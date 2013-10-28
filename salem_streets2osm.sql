--Created By: Jeffrey Meyers
--Contact: jeffrey dot alan dot meyers at gmail dot com
--For: TriMet
--Created: October 2013
--Updated: October 2013
--Derived From: rlis_streets2osm.sql initially created by Melelani Sax-Barnett in October 2012

--TODO
--*Replace SB, EB, NB, WB inside interstate names


BEGIN;

--1) create table based on Salem ctrline columns
DROP TABLE IF EXISTS salem_osm_sts CASCADE;
CREATE TABLE salem_osm_sts (
    id serial PRIMARY KEY,
    gid int REFERENCES ctrline,
    geom geometry,
	name text, --osm tag derived from fedirp + fename + fetype + fedirs
	highway text, --osm tag derived from type
	access text,
	service text,
	type text,
	fedirp text,
	fename text,
	fetype text,
	fedirs text,
	lzip text, --osm tag to be renamed addr:postcode:left
	rzip text --osm tag to be renamed addr:postcode:right
);

--2) update salem_osm_sts with ctrline columns
INSERT INTO salem_osm_sts (gid, geom, type, fedirp, fename, fetype, fedirs, lzip, rzip)
    (
    SELECT 
	ctrline.gid, 
	ctrline.geom, 
	ctrline.type, 
	TRIM(ctrline.fedirp) AS fedirp, 
	TRIM(ctrline.fename) AS fename, 
	TRIM(ctrline.fetype) AS fetype, 
	TRIM(ctrline.fedirs) AS fedirs,
	ctrline.lzip,
	ctrline.rzip
    FROM  ctrline
    );

--3) fedirp and fedirs expansion
UPDATE salem_osm_sts SET fedirp = 'Northwest'
   WHERE fedirp = 'NW';
UPDATE salem_osm_sts SET fedirs = 'Northwest'
   WHERE fedirs = 'NW';
UPDATE salem_osm_sts set fedirp = 'Southwest'
   WHERE fedirp = 'SW';
UPDATE salem_osm_sts set fedirs = 'Southwest'
   WHERE fedirs = 'SW';
UPDATE salem_osm_sts set fedirp = 'Southeast'
   WHERE fedirp = 'SE';
UPDATE salem_osm_sts set fedirs = 'Southeast'
   WHERE fedirs = 'SE';
UPDATE salem_osm_sts set fedirp = 'Northeast'
   WHERE fedirp = 'NE';
UPDATE salem_osm_sts set fedirs = 'Northeast'
   WHERE fedirs = 'NE';
UPDATE salem_osm_sts set fedirp = 'North'
   WHERE fedirp = 'N';
UPDATE salem_osm_sts set fedirs = 'North'
   WHERE fedirs = 'N';
UPDATE salem_osm_sts set fedirp = 'East'
   WHERE fedirp = 'E';
UPDATE salem_osm_sts set fedirs = 'East'
   WHERE fedirs = 'E';
UPDATE salem_osm_sts set fedirp = 'South'
   WHERE fedirp = 'S';
UPDATE salem_osm_sts set fedirs = 'South'
   WHERE fedirs = 'S';
UPDATE salem_osm_sts set fedirp = 'West'
   WHERE fedirp = 'W';
UPDATE salem_osm_sts set fedirs = 'West'
   WHERE fedirs = 'W';
   
--4) fetype expansion
UPDATE salem_osm_sts SET fetype = 'Alley'
   WHERE fetype = 'AL';
UPDATE salem_osm_sts SET fetype = 'Avenue'
   WHERE fetype = 'AV';
UPDATE salem_osm_sts SET fetype = 'Boulevard'
   WHERE fetype = 'BV';
UPDATE salem_osm_sts SET fetype = 'Camp'
   WHERE fetype = 'CP';
UPDATE salem_osm_sts SET fetype = 'Circle'
   WHERE fetype = 'CR';
UPDATE salem_osm_sts SET fetype = 'Crescent'
   WHERE fetype = 'CS';
UPDATE salem_osm_sts SET fetype = 'Court'
   WHERE fetype = 'CT';
UPDATE salem_osm_sts SET fetype = 'Drive'
   WHERE fetype = 'DR';
UPDATE salem_osm_sts SET fetype = 'Freeway'
   WHERE fetype = 'FW';
UPDATE salem_osm_sts SET fetype = 'Heights'
   WHERE fetype = 'HT';
UPDATE salem_osm_sts SET fetype = 'Highway'
   WHERE fetype = 'HW';
UPDATE salem_osm_sts SET fetype = 'Lane'
   WHERE fetype = 'LN';
UPDATE salem_osm_sts SET fetype = 'Loop'
   WHERE fetype = 'LP';
UPDATE salem_osm_sts SET fetype = 'Place'
   WHERE fetype = 'PL';
UPDATE salem_osm_sts SET fetype = 'Parkway'
   WHERE fetype = 'PY';
UPDATE salem_osm_sts SET fetype = 'Road'
   WHERE fetype = 'RD';
UPDATE salem_osm_sts SET fetype = 'Ramp'
   WHERE fetype = 'RP';
UPDATE salem_osm_sts SET fetype = 'Square'
   WHERE fetype = 'SQ';
UPDATE salem_osm_sts SET fetype = 'Street'
   WHERE fetype = 'ST';
UPDATE salem_osm_sts SET fetype = 'Trail'
   WHERE fetype = 'TR';
UPDATE salem_osm_sts SET fetype = 'Way'
   WHERE fetype = 'WY';
 
--*****************************************************************************************************************************************************************************************************************************
--Proper case basic name
--Below function from "Jonathan Brinkman" <JB(at)BlackSkyTech(dot)com> http://archives.postgresql.org/pgsql-sql/2010-09/msg00088.php

CREATE OR REPLACE FUNCTION "format_titlecase" (
  "v_inputstring" varchar
)
RETURNS varchar AS
$body$

/*
select * from Format_TitleCase('MR DOG BREATH');
select * from Format_TitleCase('each word, mcclure of this string:shall be transformed');
select * from Format_TitleCase(' EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
select * from Format_TitleCase('mcclure and others');
select * from Format_TitleCase('J & B ART');
select * from Format_TitleCase('J&B ART');
select * from Format_TitleCase('J&B ART J & B ART this''s art''s house''s problem''s 0''shay o''should work''s EACH WORD HERE SHALL BE TRANSFORMED TOO incl. mcdonald o''neil o''malley mcdervet');
*/

DECLARE
   v_Index  INTEGER;
   v_Char  CHAR(1);
   v_OutputString  VARCHAR(4000);
   SWV_InputString VARCHAR(4000);

BEGIN
   SWV_InputString := v_InputString;
   SWV_InputString := LTRIM(RTRIM(SWV_InputString)); --cures problem where string starts with blank space
   v_OutputString := LOWER(SWV_InputString);
   v_Index := 1;
   v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,1,1)) from 1 for 1); -- replaces 1st char of Output with uppercase of 1st char from Input
   WHILE v_Index <= LENGTH(SWV_InputString) LOOP
      v_Char := SUBSTR(SWV_InputString,v_Index,1); -- gets loop's working character
      IF v_Char IN('m','M','',';',':','!','?',',','.','_','-','/','&','''','(',CHR(9)) then
         --END4
         IF v_Index+1 <= LENGTH(SWV_InputString) then
            IF v_Char = '''' AND UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) <> 'S' AND SUBSTR(SWV_InputString,v_Index+2,1) <> REPEAT(' ',1) then  -- if the working char is an apost and the letter after that is not S
               v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
            ELSE 
               IF v_Char = '&' then    -- if the working char is an &
                  IF(SUBSTR(SWV_InputString,v_Index+1,1)) = ' ' then
                     v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
                  ELSE
                     v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
                  END IF;
               ELSE
                  IF UPPER(v_Char) != 'M' AND (SUBSTR(SWV_InputString,v_Index+1,1) <> REPEAT(' ',1) AND SUBSTR(SWV_InputString,v_Index+2,1) <> REPEAT(' ',1)) then
                     v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
                  END IF;
               END IF;
            END IF;

                    -- special case for handling "Mc" as in McDonald
            IF UPPER(v_Char) = 'M' AND UPPER(SUBSTR(SWV_InputString,v_Index+1,1)) = 'C' then
               v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index,1)) from v_Index for 1);
                            --MAKES THE C LOWER CASE.
               v_OutputString := OVERLAY(v_OutputString placing LOWER(SUBSTR(SWV_InputString,v_Index+1,1)) from v_Index+1 for 1);
                            -- makes the letter after the C UPPER case
               v_OutputString := OVERLAY(v_OutputString placing UPPER(SUBSTR(SWV_InputString,v_Index+2,1)) from v_Index+2 for 1);
                            --WE TOOK CARE OF THE CHAR AFTER THE C (we handled 2 letters instead of only 1 as usual), SO WE NEED TO ADVANCE.
               v_Index := v_Index+1;
            END IF;
         END IF;
      END IF; --END3

      v_Index := v_Index+1;
   END LOOP; --END2

   RETURN coalesce(v_OutputString,'');
END;
$body$
LANGUAGE 'plpgsql'
VOLATILE
CALLED ON NULL INPUT
SECURITY INVOKER
COST 100;
--*****************************************************************************************************************************************************************************************************************************

--5) run format_titlecase on each value in fename
UPDATE salem_osm_sts SET fename = format_titlecase(fename);

--6) concatenate fedirp, fename, fetype, fedirs and insert into name
UPDATE salem_osm_sts 
   SET name = subquery.name
FROM 
   (
   SELECT
	  gid,
      TRIM(CONCAT_WS(' ', 
      COALESCE(fedirp, ''), 
      COALESCE(fename, ''), 
      COALESCE(fetype, ''), 
      COALESCE(fedirs, ''))) AS name
   FROM salem_osm_sts
   ) 
AS subquery
WHERE salem_osm_sts.gid = subquery.gid;

--7) update type field with correct osm tag
UPDATE salem_osm_sts SET highway = 'motorway'
   WHERE type = '1110';
--Add name of street into link
--UPDATE salem_osm_sts SET highway = '*_link'
--   WHERE type = '1120';
UPDATE salem_osm_sts SET highway = 'tertiary_link'
   WHERE type = '1124';
UPDATE salem_osm_sts SET highway = 'primary'
   WHERE type = '1200';
UPDATE salem_osm_sts SET highway = 'trunk'
   WHERE type = '1210';
UPDATE salem_osm_sts SET highway = 'primary'
   WHERE type = '1300';
UPDATE salem_osm_sts SET highway = 'secondary'
   WHERE type = '1310';
UPDATE salem_osm_sts SET highway = 'tertiary'
   WHERE type = '1400';
UPDATE salem_osm_sts SET highway = 'residential'
   WHERE type IN ('1500', '1505');
UPDATE salem_osm_sts SET highway = 'service', service = 'alley'
   WHERE type = '1600';
UPDATE salem_osm_sts SET highway = 'residential', access = 'private'
   WHERE type IN ('1700', '1705');
UPDATE salem_osm_sts SET highway = 'service', service = 'driveway'
   WHERE type = '1800';
UPDATE salem_osm_sts SET highway = 'residential'
   WHERE type = '1900';

COMMIT;