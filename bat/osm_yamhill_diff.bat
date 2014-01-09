@echo off
setlocal enabledelayedexpansion

REM set temp database name
SET db=foobase

SET in_data_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Dec_2013\Yamhill\data\
SET osm_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Dec_2013\Yamhill\streets\backup\osm\
SET shape_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Dec_2013\Yamhill\streets\backup\shapefiles\
SET util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\
SET osm_filtered=yamhill_osm_streets.osm
SET style=streets.style

echo filtering osm
call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\yamhill.osm ^
--tf accept-ways highway=* ^
--tf reject-ways highway=construction,path,footway,pedestrian,steps,bridleway ^
--tf reject-relations ^
--un ^
--wx %osm_dir%!osm_filtered!

REM create spatially enabled database with name passed as parameter from user
echo creating database
call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -c "CREATE EXTENSION postgis;"

REM import osm file into postgis database just created
echo uploading osm into database
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%util_dir%project.sql"

REM import jurisdictional data run sql conversion script
echo uplading rlis streets into database
call shp2pgsql -I -s 2913 %in_data_dir%Addressed_Roads.shp roads | psql -U postgres -d %db% 
call psql -U postgres -d %db% -f "..\sql\yamhill_streets2osm.sql"
call shp2pgsql -I -s 2913 %util_dir%oregon_urban_buffers.shp urban_buf | psql -U postgres -d %db%

REM run diff creation sql script
echo creating diff
call psql -U postgres -d %db% -f "..\sql\generate_diff_yamhill_streets.sql" -v osm=planet_osm_line -v jurisd=yamhill_osm_sts -v buf_size=urban_buf -v diff=yamhill_streets_diff

REM TODO split diff by county

REM export diff table from postgis database to shapefile
echo exporting diff to shapefile
call pgsql2shp -k -u postgres -P password -f %shape_dir%yamhill_streets_diff.shp %db% yamhill_streets_diff

REM convert diff shapefile to osm
call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%yamhill_streets_diff.shp -o %osm_dir%yamhill_streets_diff.osm -t translations\yamhill_streets.py

REM export all streets with new attributes as shapefile and convert to osm.
call pgsql2shp -k -u postgres -P password -f %shape_dir%yamhill_streets_all.shp %db% yamhill_osm_sts
call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%yamhill_streets_all.shp -o %osm_dir%yamhill_streets_all.osm -t translations\yamhill_streets.py

call psql -U postgres -c "DROP DATABASE %db%;"
call del %osm_dir%yamhill_osm_streets.osm
