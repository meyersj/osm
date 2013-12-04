@echo off
setlocal enabledelayedexpansion

REM set temp database name
SET db=foo_base

SET in_data_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\Salem\
SET style_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\style\
SET osm_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\osm_output\
SET shape_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\shapefile_output\
SET util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\
SET osm_filtered=salem_osm_streets.osm
SET style=streets.style

echo filtering osm
call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\marion.osm ^
--rx G:\PUBLIC\OpenStreetMap\data\osm\polk.osm ^
--m ^
--tf accept-ways highway=* ^
--tf reject-ways highway=construction,path,footway,pedestrian,steps,bridleway ^
--tf reject-relations ^
--un ^
--wx %osm_dir%!osm_filtered!

REM create spatially enabled database with name passed as parameter from user
echo creating database
call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -c "CREATE EXTENSION postgis;"
REM call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\postgis.sql"
REM call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\spatial_ref_sys.sql"

REM import osm file into postgis database just created
echo uploading osm into database
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%util_dir%project.sql"

REM import jurisdictional data run sql conversion script
echo uplading rlis streets into database
call shp2pgsql -I -s 2913 %in_data_dir%ctrline.shp ctrline | psql -U postgres -d %db% 
call psql -U postgres -d %db% -f "%util_dir%salem_streets2osm.sql"
call shp2pgsql -I -s 2913 %util_dir%oregon_urban_buffers.shp urban_buf | psql -U postgres -d %db%

REM run diff creation sql script
echo creating diff
call psql -U postgres -d %db% -f "..\sql\generate_diff_salem_streets.sql" -v osm=planet_osm_line -v jurisd=salem_osm_sts -v buf_size=urban_buf -v diff=salem_streets_diff

REM TODO split diff by county

REM export diff table from postgis database to shapefile
echo exporting diff to shapefile
call pgsql2shp -k -u postgres -P password -f %shape_dir%salem_streets_diff.shp %db% salem_streets_diff

REM convert diff shapefile to osm
call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%salem_streets_diff.shp -o %osm_dir%salem_streets_diff.osm -t translations\salem_streets.py

call psql -U postgres -c "DROP DATABASE %db%;"
