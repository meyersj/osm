REM TODO reorganize paths

@echo off
setlocal enabledelayedexpansion

REM set temp database name
SET db=foo_base

SET in_data_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\Salem\

SET osm_dir=C:\Users\meyersj\Documents\GitHub\osm\test\salem\
SET shape_dir=C:\Users\meyersj\Documents\GitHub\osm\test\salem\
REM SET osm_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\osm_output\
REM SET shape_dir=G:\PUBLIC\OpenStreetMap\data\OSM_update\Oct_2013\Salem_Area\shapefile_output\


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
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! %osm_dir%!osm_filtered!
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call psql -U postgres -d %db% -c "ALTER TABLE planet_osm_line RENAME TO osm_filtered"
call psql -U postgres -d %db% -c "ALTER INDEX planet_osm_line_index RENAME TO osm_filtered_index"

REM -import false positive osm file
call osm2pgsql -U postgres -d %db% -S %util_dir%!style! "../test/salem_fpos.osm"
call psql -U postgres -d %db% -f "%util_dir%project.sql"
call psql -U postgres -d %db% -c "ALTER TABLE planet_osm_line RENAME TO fpos"
call psql -U postgres -d %db% -c "ALTER INDEX planet_osm_line_index RENAME TO fpos_index"


REM import jurisdictional data run sql conversion script
echo uplading rlis streets into database
call shp2pgsql -I -s 2913 %in_data_dir%ctrline.shp ctrline | psql -U postgres -d %db% 
call psql -U postgres -d %db% -f "..\sql\salem_streets2osm.sql"
call shp2pgsql -I -s 2913 %util_dir%oregon_urban_buffers.shp urban_buf | psql -U postgres -d %db%


REM build rm_fpos.sql and generate_diff.sql using build_sql.py
call python ..\sql\build_sql.py ..\sql\fpos_template.sql ..\sql\rm_fpos.sql %util_dir%salem_streets_fields.txt fpos
call python ..\sql\build_sql.py ..\sql\diff_template.sql ..\sql\generate_diff.sql %util_dir%salem_streets_fields.txt diff

REM run diff creation sql script
echo creating diff
call psql -U postgres -d %db% -f "../sql/rm_fpos.sql" -v fpos=fpos -v jurisd=salem_osm_sts -v fpos_final=salem_osm_sts_fpos_rm
echo generating diff table
call psql -U postgres -d %db% -f "../sql/generate_diff.sql" -v osm=osm_filtered -v jurisd=salem_osm_sts -v buf_size=urban_buf -v diff=salem_streets_diff


REM TODO split diff by county

REM export diff table from postgis database to shapefile
echo exporting diff to shapefile
call pgsql2shp -k -u postgres -P password -f %shape_dir%salem_streets_diff.shp %db% salem_streets_diff

REM convert diff shapefile to osm
call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%salem_streets_diff.shp -o %osm_dir%salem_streets_diff.osm -t translations\salem_streets.py

REM export all streets with new attributes as shapefile and convert to osm.
call pgsql2shp -k -u postgres -P password -f %shape_dir%salem_streets_all.shp %db% salem_osm_sts
call python %util_dir%ogr2osm\ogr2osm.py %shape_dir%salem_streets_all.shp -o %osm_dir%salem_streets_all.osm -t translations\salem_streets.py

call psql -U postgres -c "DROP DATABASE %db%;"
call del %osm_dir%salem_osm_streets.osm
