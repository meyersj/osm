@echo off
setlocal enabledelayedexpansion

set osm_dir=G:\PUBLIC\OpenStreetMap\data\osm\
set out_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\osm_git\metro_exports\output\
set util_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\utilities\
set db=foo_trail

call osmosis --rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--m --m --m --m ^
--wkv keyValueList=highway.path,highway.footway,highway.cycleway,highway.pedrestrian,highway.steps,highway.bridleway ^
--tf reject-ways area=yes ^
--tf reject-relations ^
--un outPipe.0="trails" ^
--rx !osm_dir!multnomah.osm ^
--rx !osm_dir!clackamas.osm ^
--rx !osm_dir!washington.osm ^
--rx !osm_dir!yamhill.osm ^
--rx !osm_dir!clark.osm ^
--m --m --m --m ^
--tf accept-ways motor_vehicle=no ^
--tf accept-ways highway=track ^
--tf reject-ways area=yes ^
--tf reject-relations ^
--un outPipe.0="track" ^
--m inPipe.0="trails" inPipe.1="track" ^
--wx file="!out_dir!trails_all.osm"

call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -c "CREATE EXTENSION postgis;"
call osm2pgsql -U postgres -d %db% -S %util_dir%trails.style !out_dir!trails_all.osm
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call pgsql2shp -k -u postgres -P password -f  !out_dir!osm_trails.shp %db% planet_osm_line
