@echo off
setlocal enabledelayedexpansion


REM -Usage: spatial_db my_database_name

REM choose default database name instead of taking name as parameter
SET db=temp_database_11010

REM take streets or trails keyword as parameter to affect how osmosis filters
SET type=%1


SET rlis_dir=G:\Rlis\
SET osm_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Dec_2013\RLIS\streets\backup\osm\
SET shape_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Dec_2013\RLIS\streets\backup\shapefiles\
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
  --m --m ^
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
REM call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\postgis.sql"
REM call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\spatial_ref_sys.sql"

REM -import osm file into postgis database just created
echo uploading osm into database
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call shp2pgsql -I -s 2913 %util_dir%oregon_urban_buffers.shp urban_buf | psql -U postgres -d %db% 
call shp2pgsql -I -s 2913 -W LATIN1 %rlis_dir%BOUNDARY\co_fill.shp co_fill | psql -U postgres -d %db% 


IF %type%==streets (
  REM import RLIS streets file and run sql conversion script and diff generation
  echo uplading rlis streets into database
  call shp2pgsql -I -s 2913 %rlis_dir%STREETS\streets.shp rlis_streets | psql -U postgres -d %db% 
  call psql -U postgres -d %db% -f "%util_dir%rlis_streets2osm.sql"
  
  echo generating diff table
  call psql -U postgres -d %db% -f "../sql/generate_diff_rlis_streets.sql" -v osm=planet_osm_line -v jurisd=osm_sts -v buf_size=urban_buf -v diff=rlis_streets_diff

  call psql -U postgres -d %db% -f "../sql/split_county_rlis.sql"


  REM export generated diff
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff.shp %db% rlis_streets_diff
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff.shp %db% rlis_streets_diff_wash
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff.shp %db% rlis_streets_diff_clack
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff.shp %db% rlis_streets_diff_mult
  call pgsql2shp -k -u postgres -P password -f  %shape_dir%rlis_streets_diff.shp %db% rlis_streets_diff_yam


  REM ogr2osm.py script to export shapefile diff to osm file
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff.shp -o %osm_dir%rlis_streets_diff.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_wash.shp -o %osm_dir%rlis_streets_diff_wash.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_clack.shp -o %osm_dir%rlis_streets_diff_clack.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_mult.shp -o %osm_dir%rlis_streets_diff_mult.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
  call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%rlis_streets_diff_yam.shp -o %osm_dir%rlis_streets_diff_yam.osm -t %util_dir%ogr2osm\translations\rlis_streets.py
)


REM TODO create generate_diff_rlis_trails.sql
IF %type%==trails (

  REM -import RLIS file and run sql conversion script
  echo uploading rlis trails into database
  call shp2pgsql -I -s 2913 %rlis_dir%\TRANSIT\trails.shp rlis_trails | psql -U postgres -d %db% 
  call psql -U postgres -d %db% -f "%util_dir%rlis_trails2osm.sql"

  
  call psql -U postgres -d %db% -f "generate_diff_rlis_trails.sql" -v REM TODO corrections...........................
  
  REM -export line table from postgis database to shapefile
  echo exporting osm and rlis trails to shapefile
  call pgsql2shp -k -u postgres -P password -f %shape_dir%osm_trails_2913.shp %db% planet_osm_line
  call pgsql2shp -k -u postgres -P password -f %shape_dir%rlis_trails_2913.shp %db% osm_trails
  call python process_diff_v2.py %shape_dir%rlis_trails_2913.shp %shape_dir%osm_trails_2913.shp rlis_trails_diff.shp
  
  REM TODO ogr2osm.py script to export shapefile diff to osm file
  call python %ogr2osm_dir%ogr2osm.py rlis_trails_diff.shp -o %osm_dir%rlis_trails_diff.osm -t translations\rlis_trails.py

)


call psql -U postgres -c "DROP DATABASE %db%;"

