--Created By: Jeffrey Meyers
--Contact: jeffrey dot alan dot meyers at gmail dot com
--For: TriMet
--Created on: October 2013
--Updated on: October 2013
--Derived From: rlis_streets2osm.sql initially created by Melelani Sax-Barnett in October 2012

--TODO
--*Replace SB, EB, NB, WB inside interstate names


BEGIN;

--1) create table based on Salem ctrline columns
DROP TABLE IF EXISTS yamhill_osm_sts CASCADE;
CREATE TABLE yamhill_osm_sts (
  id serial PRIMARY KEY,
  gid int REFERENCES roads,
  geom geometry, --geometry for osm
	name text, --osm tag derived from addr_pd + addr_sn + addr_st + addr_sd
	highway text, --osm tag derived from type
	surface text, --osm tag
  access text, --osm tag populated where owner=private
  
  addr_pd text,
  addr_sn text,
  addr_st text,
  addr_sd text,
  owner text,
  zipcode text --osm tag to be renamed addr:postcode
);

--2) update salem_osm_sts with ctrline columns
INSERT INTO yamhill_osm_sts (gid, geom, addr_pd, addr_sn, addr_st, addr_sd, owner, surface, zipcode)
(
  SELECT r.gid, 
	       r.geom, 
	       TRIM(r.addr_pd) AS addr_pd, 
	       TRIM(r.addr_sn) AS addr_sn, 
	       TRIM(r.addr_st) AS addr_st, 
	       TRIM(r.addr_sd) AS addr_sd,
	       r.owner,
         r.surface,
         r.zipcode
    FROM roads AS r
);

--3) addr_pd and addr_sd expansion
UPDATE yamhill_osm_sts SET addr_pd = 'Northwest'
   WHERE addr_pd = 'NW';
UPDATE yamhill_osm_sts SET addr_sd = 'Northwest'
   WHERE addr_sd = 'NW';
UPDATE yamhill_osm_sts set addr_pd = 'Southwest'
   WHERE addr_pd = 'SW';
UPDATE yamhill_osm_sts set addr_sd = 'Southwest'
   WHERE addr_sd = 'SW';
UPDATE yamhill_osm_sts set addr_pd = 'Southeast'
   WHERE addr_pd = 'SE';
UPDATE yamhill_osm_sts set addr_sd = 'Southeast'
   WHERE addr_sd = 'SE';
UPDATE yamhill_osm_sts set addr_pd = 'Northeast'
   WHERE addr_pd = 'NE';
UPDATE yamhill_osm_sts set addr_sd = 'Northeast'
   WHERE addr_sd = 'NE';
UPDATE yamhill_osm_sts set addr_pd = 'North'
   WHERE addr_pd = 'N';
UPDATE yamhill_osm_sts set addr_sd = 'North'
   WHERE addr_sd = 'N';
UPDATE yamhill_osm_sts set addr_pd = 'East'
   WHERE addr_pd = 'E';
UPDATE yamhill_osm_sts set addr_sd = 'East'
   WHERE addr_sd = 'E';
UPDATE yamhill_osm_sts set addr_pd = 'South'
   WHERE addr_pd = 'S';
UPDATE yamhill_osm_sts set addr_sd = 'South'
   WHERE addr_sd = 'S';
UPDATE yamhill_osm_sts set addr_pd = 'West'
   WHERE addr_pd = 'W';
UPDATE yamhill_osm_sts set addr_sd = 'West'
   WHERE addr_sd = 'W';
   
--4) addr_st expansion
UPDATE yamhill_osm_sts SET addr_st = 'Alley'
   WHERE addr_st = 'ALY';
UPDATE yamhill_osm_sts SET addr_st = 'Avenue'
   WHERE addr_st = 'AVE';
UPDATE yamhill_osm_sts SET addr_st = 'Boulevard'
   WHERE addr_st = 'BLVD';
UPDATE yamhill_osm_sts SET addr_st = 'Bypass'
   WHERE addr_st = 'BYP';
UPDATE yamhill_osm_sts SET addr_st = 'Circle'
   WHERE addr_st = 'CIR';
UPDATE yamhill_osm_sts SET addr_st = 'Court'
   WHERE addr_st = 'CT';
UPDATE yamhill_osm_sts SET addr_st = 'Drive'
   WHERE addr_st = 'DR';
UPDATE yamhill_osm_sts SET addr_st = 'Extension'
   WHERE addr_st = 'EXT';
UPDATE yamhill_osm_sts SET addr_st = 'Heights'
   WHERE addr_st = 'HTS';
UPDATE yamhill_osm_sts SET addr_st = 'Highway'
   WHERE addr_st = 'HWY';
UPDATE yamhill_osm_sts SET addr_st = 'Lane'
   WHERE addr_st = 'LN';
UPDATE yamhill_osm_sts SET addr_st = 'Loop'
   WHERE addr_st = 'LP' OR addr_st = 'LOOP';
UPDATE yamhill_osm_sts SET addr_st = 'Place'
   WHERE addr_st = 'PL';
UPDATE yamhill_osm_sts SET addr_st = 'Parkway'
   WHERE addr_st = 'PKWY';
UPDATE yamhill_osm_sts SET addr_st = 'Road'
   WHERE addr_st = 'RD';
UPDATE yamhill_osm_sts SET addr_st = 'Street'
   WHERE addr_st = 'ST';
UPDATE yamhill_osm_sts SET addr_st = 'Way'
   WHERE addr_st = 'WAY';
UPDATE yamhill_osm_sts SET addr_st = NULL
   WHERE addr_st IN ('X', 'Y', 'Z');
 
--*****************************************************************************************
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
--*****************************************************************************************

--5) run format_titlecase on each value in addr_sn
UPDATE yamhill_osm_sts SET addr_sn = format_titlecase(addr_sn);

--6) concatenate addr_pd, addr_sn, addr_st, addr_sd and insert into name
UPDATE yamhill_osm_sts 
  SET name = subquery.name
  FROM 
  (
    SELECT gid,
           TRIM(CONCAT_WS(' ', 
           COALESCE(addr_pd, ''), 
           COALESCE(addr_sn, ''), 
           COALESCE(addr_st, ''), 
           COALESCE(addr_sd, ''))) AS name
   FROM yamhill_osm_sts
   ) 
AS subquery
WHERE yamhill_osm_sts.gid = subquery.gid;

--7) update type field with correct osm tag
UPDATE yamhill_osm_sts SET highway = 'track'
  WHERE owner IN ('BLM', 'USFS');
UPDATE yamhill_osm_sts SET access = 'private'
  WHERE owner IN ('Private', 'private');

COMMIT;
