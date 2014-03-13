@echo off
setlocal enabledelayedexpansion

set osm_dir=G:\PUBLIC\OpenStreetMap\data\osm\
set out_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\metro_exports\
set util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\
set db=foo_bike


call osmosis --rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--m --m --m --m ^
--wk keyList=,bicycle,cycleway,cycleway:left,cycleway:right, RLIS:bicycle ^
--tf reject-ways area=yes ^
--tf reject-ways bicycle=no,dismount ^
--tf reject-relations ^
--un ^
outPipe.0="bike" ^
--rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--m --m --m --m ^
--tf accept-ways highway=cycleway ^
--tf reject-ways area=yes ^
--tf reject-ways bicycle=no,dismount ^
--tf reject-relations ^
--un ^
outPipe.1="highway" ^
inPipe.0="bike" ^
inPipe.1="highway" ^
--m ^
--un ^
--wx !out_dir!bicycle_all.osm


call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -c "CREATE EXTENSION postgis;"
call osm2pgsql -U postgres -d %db% -S %util_dir%bike.style !out_dir!bicycle_all.osm
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call pgsql2shp -k -u postgres -P password -f  !out_dir!osm_bike_rte.shp %db% planet_osm_line

