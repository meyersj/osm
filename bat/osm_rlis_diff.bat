@echo off
setlocal enabledelayedexpansion

REM -Usage: spatial_db my_database_name

REM choose default database name instead of taking name as parameter
SET db=foo_base

REM take streets or trails keyword as parameter to affect how osmosis filters
SET type=%1

REM ****************************************************************
REM SET shape_dir AND osm_dir TO CORRECT LOCATIONS BEFORE RUNNING!!!
REM ****************************************************************


SET rlis_dir=G:\Rlis\
SET osm_dir=..\test\rlis\
SET shape_dir=..\test\rlis\
SET util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\


SET match=False

IF %type%==trails (
  SET match=True
  SET style=trails.style
  SET osm_filtered=osm_trails.osm

  echo filtering osm
  call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\multnomah.osm ^
  --rx G:\PUBLIC\OpenStreetMap\data\osm\washington.osm ^
  --rx G:\PUBLIC\OpenStreetMap\data\osm\clackamas.osm ^
  --rx G:\PUBLIC\OpenStreetMap\data\osm\yamhill.osm ^
  --m --m --m ^
  --tf reject-relations ^
  --wkv keyValueListFile=%util_dir%trail_tags.txt ^
  --un ^
  --wx %osm_dir%!osm_filtered!
)

IF %type%==streets (
  SET match=True
  SET style=streets.style
  SET osm_filtered=osm_streets.osm

  echo filtering osm
  call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\multnomah.osm ^
  --rx G:\PUBLIC\OpenStreetMap\data\osm\washington.osm ^
  --rx G:\PUBLIC\OpenStreetMap\data\osm\clackamas.osm ^
  --rx G:\PUBLIC\OpenStreetMap\data\osm\yamhill.osm ^
  --m --m --m ^
  --tf accept-ways highway=* ^
  --tf reject-ways highway=construction,path,footway,pedestrian,steps,bridleway ^
  --tf reject-relations ^
  --un ^
  --wx %osm_dir%!osm_filtered!
)

IF %match%==False (
  echo invalid input processing type, specify 'streets' or 'trails'
  exit /B
)

REM -create spatially enabled database with name passed as parameter from user
echo creating database
call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -c "CREATE EXTENSION postgis;"

REM -import osm file into postgis database just created
echo uploading osm into database
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call psql -U postgres -d %db% -c "ALTER TABLE planet_osm_line RENAME TO osm_filtered"
call psql -U postgres -d %db% -c "ALTER INDEX planet_osm_line_index RENAME TO osm_filtered_index"

REM -import false positive osm file
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! "../test/rlis_fpos.osm"
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call psql -U postgres -d %db% -c "ALTER TABLE planet_osm_line RENAME TO fpos"
call psql -U postgres -d %db% -c "ALTER INDEX planet_osm_line_index RENAME TO fpos_index"


call shp2pgsql -I -s 2913 %util_dir%oregon_urban_buffers.shp urban_buf | psql -U postgres -d %db% 
call shp2pgsql -I -s 2913 -W LATIN1 %rlis_dir%BOUNDARY\co_fill.shp co_fill | psql -U postgres -d %db% 

IF %type%==streets (
  REM import RLIS streets file and run sql conversion script and diff generation
  echo uplading rlis streets into database
  
  call shp2pgsql -I -s 2913 %rlis_dir%STREETS\streets.shp rlis_streets | psql -U postgres -d %db% 
  call psql -U postgres -d %db% -f "%util_dir%rlis_streets2osm.sql"
  
  REM build rm_fpos.sql and generate_diff.sql using build_sql.py
  call python ..\sql\build_sql.py fpos ..\sql\fpos_template.sql ..\sql\rm_fpos.sql %util_dir%rlis_streets_fields.txt
  call python ..\sql\build_sql.py diff ..\sql\diff_template.sql ..\sql\generate_diff.sql %util_dir%rlis_streets_fields.txt
  call python ..\sql\build_sql.py split ..\sql\split_by_county.sql %util_dir%rlis_counties.txt rlis_streets


  call psql -U postgres -d %db% -f "../sql/rm_fpos.sql" -v fpos=fpos -v jurisd=osm_sts -v fpos_final=osm_sts_fpos_rm

  echo generating diff table
  call psql -U postgres -d %db% -f "../sql/generate_diff.sql" -v osm=osm_filtered -v jurisd=osm_sts_fpos_rm -v buf_size=urban_buf -v diff=rlis_streets_diff

  call psql -U postgres -d %db% -f "../sql/split_by_county.sql"

  REM export generated diff
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff.shp %db% rlis_streets_diff
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff_wash.shp %db% rlis_streets_diff_wash
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff_clack.shp %db% rlis_streets_diff_clack
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff_mult.shp %db% rlis_streets_diff_mult
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff_yam.shp %db% rlis_streets_diff_yam

  REM ogr2osm.py script to export shapefile diff to osm file
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff.shp -o %osm_dir%rlis_streets_diff.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_wash.shp -o %osm_dir%rlis_streets_diff_wash.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_clack.shp -o %osm_dir%rlis_streets_diff_clack.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_mult.shp -o %osm_dir%rlis_streets_diff_mult.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_yam.shp -o %osm_dir%rlis_streets_diff_yam.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
)

REM TODO update trails portion to use false positives
IF %type%==trails (

  REM -import RLIS file and run sql conversion script
  echo uploading rlis trails into database
  call shp2pgsql -I -s 2913 %rlis_dir%\TRANSIT\trails.shp rlis_trails | psql -U postgres -d %db% 
  call psql -U postgres -d %db% -f "%util_dir%rlis_trails2osm.sql"

  
  call psql -U postgres -d %db% -f "generate_diff_rlis_trails.sql" -v osm=planet_osm_line -v jurisd=osm_trails -v buf_size=urban_buf -v diff=rlis_trails_diff -f "../sql/generate_diff_rlis_trails.sql"
  
  call psql -U postgres -d %db% -f "../sql/split_county_rlis_trails.sql"


  REM export generated diff
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_trails_diff.shp %db% rlis_trails_diff
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_trails_diff_wash.shp %db% rlis_trails_diff_wash
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_trails_diff_clack.shp %db% rlis_trails_diff_clack
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_trails_diff_mult.shp %db% rlis_trails_diff_mult
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_trails_diff_yam.shp %db% rlis_trails_diff_yam


  REM ogr2osm.py script to export shapefile diff to osm file
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_trails_diff.shp -o %osm_dir%rlis_trails_diff.osm -t %util_dir%ogr2osm\translations\rlis_trails.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_trails_diff_wash.shp -o %osm_dir%rlis_trails_diff_wash.osm -t %util_dir%ogr2osm\translations\rlis_trails.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_trails_diff_clack.shp -o %osm_dir%rlis_trails_diff_clack.osm -t %util_dir%ogr2osm\translations\rlis_trails.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_trails_diff_mult.shp -o %osm_dir%rlis_trails_diff_mult.osm -t %util_dir%ogr2osm\translations\rlis_trails.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_trails_diff_yam.shp -o %osm_dir%rlis_trails_diff_yam.osm -t %util_dir%ogr2osm\translations\rlis_trails.py
)

call psql -U postgres -c "DROP DATABASE %db%;"

