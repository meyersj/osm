@echo off
setlocal enabledelayedexpansion

set osm_dir=G:\PUBLIC\OpenStreetMap\data\osm\
set out_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\osm_git\metro_exports\output\
set util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\
set db=foo_bike_ped

call osmosis --rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--rx !osm_dir!marion.osm ^
--m --m --m --m --m ^
--wk keyList=bicycle,cycleway,cycleway:left,cycleway:right,RLIS:bicycle ^
--tf reject-ways area=yes ^
--tf reject-ways bicycle=no,dismount ^
--tf reject-relations ^
--un outPipe.0="bike" ^
--rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--rx !osm_dir!marion.osm ^
--m --m --m --m --m ^
--tf accept-ways highway=cycleway ^
--tf reject-ways area=yes ^
--tf reject-ways bicycle=no,dismount ^
--tf reject-relations ^
--un outPipe.0="highway" ^
--m inPipe.0="bike" inPipe.1="highway" ^
--un outPipe.0="bike_all" ^
--rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--rx !osm_dir!marion.osm ^
--m --m --m --m --m ^
--wkv keyValueList=highway.path,highway.footway,highway.cycleway,highway.pedrestrian,highway.steps,highway.bridleway ^
--tf reject-ways area=yes ^
--tf reject-relations ^
--un outPipe.0="trail" ^
--rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--rx !osm_dir!marion.osm ^
--m --m --m --m --m ^
--tf accept-ways motor_vehicle=no ^
--tf accept-ways highway=track ^
--tf reject-ways area=yes ^
--tf reject-relations ^
--un outPipe.0="track" ^
--m inPipe.0="trail" inPipe.1="track" ^
--un outPipe.0="trail_all" ^
--m inPipe.0="bike_all" inPipe.1="trail_all" ^
--wx file="!out_dir!bike_ped.osm"

call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -c "CREATE EXTENSION postgis;"
call osm2pgsql -U postgres -d %db% -S %util_dir%bike_ped.style !out_dir!bike_ped.osm
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call pgsql2shp -k -u postgres -P password -m !util_dir!field_remap.txt -f !out_dir!osm_bike_ped.shp %db% planet_osm_line
call psql -U postgres -c "DROP DATABASE %db%;"
