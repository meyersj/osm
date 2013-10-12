REM -Usage: spatial_db my_database_name

SET db=%1
SET rlis=P:\osm\rlis2osm_verify\postgis\rlis\
SET style=P:\osm\rlis2osm_verify\7_county\test.style
SET osm_dir=P:\osm\rlis2osm_verify\postgis\output\osmfiles\
SET shape_dir=P:\osm\rlis2osm_verify\postgis\output\shapefiles\

call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\multnomah.osm ^
--rx G:\PUBLIC\OpenStreetMap\data\osm\washington.osm ^
--rx G:\PUBLIC\OpenStreetMap\data\osm\clackamas.osm ^
--m --m ^
--tf reject-relations ^
--wkv keyValueListFile=P:\osm\trail_tags.txt ^
--un ^
--wx %osm_dir%osm_trails.osm

REM -filter Tri-County region osm files for only highways
::call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\multnomah.osm ^
::--rx G:\PUBLIC\OpenStreetMap\data\osm\washington.osm ^
::--rx G:\PUBLIC\OpenStreetMap\data\osm\clackamas.osm ^
::--m --m ^
::--tf accept-ways highway=* ^
::--tf reject-relations ^
::--un ^
::--wx %osm_dir%osm_streets.osm

REM -create spatially enabled database with name passed as parameter from user
call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\postgis.sql"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\spatial_ref_sys.sql"

REM -import highways osm file into postgis database just created
call osm2pgsql -U postgres -d %db% -S %style% %osm_dir%osm_trails.osm
call psql -U postgres -d %db% -f "%rlis%project.sql"

REM -import RLIS file and run sql conversion script
call shp2pgsql -I -s 2913 %rlis%trails.shp rlis_trails | psql -U postgres -d %db% 
call psql -U postgres -d %db% -f "%rlis%rlis_trails2osm.sql"

REM -export line table from postgis database to shapefile
call pgsql2shp -k -u postgres -P password -f %shape_dir%osm_trails_2913.shp %db% planet_osm_line
call pgsql2shp -k -u postgres -P password -f %shape_dir%rlis_trails_2913.shp %db% osm_trails

REM call python python_script_for_processing.py %shapefile%
REM -cleanup
call psql -U postgres -c "DROP DATABASE %db%;"



call python process_diff_v2.py %shape_dir%rlis_trails_2913.shp %shape_dir%osm_trails_2913.shp


