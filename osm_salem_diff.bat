@echo off
setlocal enabledelayedexpansion

REM choose default database name instead of taking name as parameter
SET db=salem_v32462

SET in_data_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\Salem\
SET style_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\style\
SET osm_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\osm_output\
SET shape_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\shapefile_output\
SET util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\
SET ogr2osm_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\ogr2osm\
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

REM -create spatially enabled database with name passed as parameter from user
echo creating database
call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\postgis.sql"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\spatial_ref_sys.sql"

REM -import osm file into postgis database just created
echo uploading osm into database
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%util_dir%project.sql"

REM -import RLIS streets file and run sql conversion script
echo uplading rlis streets into database
call shp2pgsql -I -s 2913 %in_data_dir%ctrline.shp ctrline | psql -U postgres -d %db% 
call psql -U postgres -d %db% -f "%util_dir%salem_streets2osm.sql"

REM -export line table from postgis database to shapefile
echo exporting osm and rlis streets to shapefile
call pgsql2shp -k -u postgres -P password -f %shape_dir%osm_streets_2913.shp %db% planet_osm_line
call pgsql2shp -k -u postgres -P password -f %shape_dir%salem_streets_2913.shp %db% salem_osm_sts

REM -create diff 
call python process_diff_v2.py %shape_dir%salem_streets_2913.shp %shape_dir%osm_streets_2913.shp salem_streets_diff.shp %shape_dir% %util_dir%salem_streets_fields.txt

REM TODO split diff by county
call python %ogr2osm_dir%ogr2osm.py %shape_dir%salem_streets_diff.shp -o %osm_dir%salem_streets_diff.osm -t translations\salem_streets.py

call psql -U postgres -c "DROP DATABASE %db%;"
