REM -Usage: spatial_db my_database_name

SET db=%1
SET style=P:\osm\rlis2osm_verify\7_county\test.style
SET osm_dir=P:\osm\rlis2osm_verify\postgis\output\osmfiles\
SET shape_dir=P:\osm\rlis2osm_verify\postgis\output\shapefiles\

REM -filter Tri-County region osm files for only highways
call osmosis --rx G:\PUBLIC\OpenStreetMap\data\osm\multnomah.osm ^
--rx G:\PUBLIC\OpenStreetMap\data\osm\washington.osm ^
--rx G:\PUBLIC\OpenStreetMap\data\osm\clackamas.osm ^
--m --m ^
--tf accept-ways highway=* ^
--tf reject-relations ^
--un ^
--wx %osm_dir%osm_streets.osm

REM -create spatially enabled database with name passed as parameter from user
call psql -U postgres -c "CREATE DATABASE %db%;"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\postgis.sql"
call psql -U postgres -d %db% -f "C:\Program Files\PostgreSQL\9.2\share\contrib\postgis-2.0\spatial_ref_sys.sql"

REM -import highways osm file into postgis database just created
call osm2pgsql -U postgres -d %db% -S %style% -l %osm_dir%osm_streets.osm
REM -export line table from postgis database to shapefile
call pgsql2shp -k -u postgres -P password -f %shape_dir%osm_streets.shp %db% planet_osm_line
REM -reproject output to NAD83(HARN)/Oregon North (ft) 
call ogr2ogr -t_srs EPSG:2913 %shape_dir%osm_streets_2913.shp %shape_dir%osm_streets.shp

REM -cleanup
call psql -U postgres -c "DROP DATABASE %db%;"
del %shape_dir%osm_streets.*