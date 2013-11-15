@echo off
setlocal enabledelayedexpansion


REM -Usage: spatial_db my_database_name

REM choose default database name instead of taking name as parameter
SET db=temp_database_11010

REM take streets or trails keyword as parameter to affect how osmosis filters
SET type=%1


SET rlis_dir=P:\osm\rlis2osm_verify\postgis\rlis\
SET style_dir=P:\osm\rlis2osm_verify\7_county\
SET osm_dir=P:\osm\rlis2osm_verify\postgis\output\osmfiles\
SET shape_dir=P:\osm\rlis2osm_verify\postgis\output\shapefiles\
SET ogr2osm_dir=G:\PUBLIC\OpenStreetMap\data\RLIS_update_2013\ogr2osm\

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
  --wkv keyValueListFile=P:\osm\trail_tags.txt ^
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
  --m --m ^
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
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\postgis.sql"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\spatial_ref_sys.sql"

REM -import osm file into postgis database just created
echo uploading osm into database
call osm2pgsql -U postgres -d %db% -S %style_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%rlis_dir%project.sql"


IF %type%==streets (
  REM -import RLIS streets file and run sql conversion script
  echo uplading rlis streets into database
  call shp2pgsql -I -s 2913 %rlis_dir%streets.shp rlis_streets | psql -U postgres -d %db% 
  call psql -U postgres -d %db% -f "%rlis_dir%rlis_streets2osm.sql"


  REM -export line table from postgis database to shapefile
  echo exporting osm and rlis streets to shapefile
  call pgsql2shp -k -u postgres -P password -f %shape_dir%osm_streets_2913.shp %db% planet_osm_line
  call pgsql2shp -k -u postgres -P password -f %shape_dir%rlis_streets_2913.shp %db% osm_sts
  call python process_diff_v2.py %shape_dir%rlis_streets_2913.shp %shape_dir%osm_streets_2913.shp rlis_streets_diff.shp

  REM TODO ogr2osm.py script to export shapefile diff to osm file
  call python %ogr2osm_dir%ogr2osm.py rlis_streets_diff.shp -o %osm_dir%rlis_streets_diff.osm -t translations\rlis_streets.py
)

IF %type%==trails (

  REM -import RLIS file and run sql conversion script
  echo uploading rlis trails into database
  call shp2pgsql -I -s 2913 %rlis_dir%trails.shp rlis_trails | psql -U postgres -d %db% 
  call psql -U postgres -d %db% -f "%rlis_dir%rlis_trails2osm.sql"

  REM -export line table from postgis database to shapefile
  echo exporting osm and rlis trails to shapefile
  call pgsql2shp -k -u postgres -P password -f %shape_dir%osm_trails_2913.shp %db% planet_osm_line
  call pgsql2shp -k -u postgres -P password -f %shape_dir%rlis_trails_2913.shp %db% osm_trails
  call python process_diff_v2.py %shape_dir%rlis_trails_2913.shp %shape_dir%osm_trails_2913.shp rlis_trails_diff.shp
  
  REM TODO ogr2osm.py script to export shapefile diff to osm file
  call python %ogr2osm_dir%ogr2osm.py rlis_trails_diff.shp -o %osm_dir%rlis_trails_diff.osm -t translations\rlis_trails.py

)


call psql -U postgres -c "DROP DATABASE %db%;"

