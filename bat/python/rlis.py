import subprocess, sys, os, logging
from os import path

db = 'foo_base'
data_dir='G:/Rlis'
osm_dir = 'C:/users/meyersj/documents/github/osm/test/rlis'
shp_dir = 'C:/users/meyersj/documents/github/osm/test/rlis'
util_dir = 'G:/PUBLIC/OpenStreetMap/data/OSM_update/utilities'
logging.basicConfig(filename='rlis.log', level=logging.DEBUG)



class Diff(object):

    def __init__(self, db, data_dir, osm_dir, shp_dir, util_dir, stype):
        self.db = db
        self.data_dir = data_dir
        self.osm_dir = osm_dir
        self.shp_dir = shp_dir
        self.util_dir = util_dir
        self.osm_filtered = None
        self.style = None
        self.trail_tags = 'highway=path,footway,cycleway,pedestrian,steps,bridleway,track' 
        self.street_tags = 'highway=* --tf reject-ways highway=construction,path,footway,pedestrian,steps,bridleway'
        self.stype = stype

    def osmosis(self):
        tags = ''
        if self.stype == 'streets':
            self.osm_filtered = path.join(self.osm_dir, 'filtered_streets.osm')
            tags = self.street_tags
        elif self.stype == 'trails':
            self.osm_filtered = path.join(self.osm_dir, 'filtered_trails.osm')
            tags = self.trail_tags
        else:
            logging.error('incorrect argument, trails or streets only')
        
        osmosis = ' '.join('''osmosis 
        --rx G:\PUBLIC\OpenStreetMap\data\osm\multnomah.osm 
        --rx G:\PUBLIC\OpenStreetMap\data\osm\washington.osm 
        --rx G:\PUBLIC\OpenStreetMap\data\osm\clackamas.osm
        --rx G:\PUBLIC\OpenStreetMap\data\osm\yamhill.osm
        --m --m --m
        --tf accept-ways {0}
        --tf reject-relations
        --un
        --wx {1}'''.split()).format(tags, self.osm_filtered) 

        try:
            subprocess.check_call(osmosis, shell=True)
        except subprocess.CalledProcessError:
            logging.error('failed to run osmosis')


    def create_db(self):
        create = 'psql -U postgres -c "CREATE DATABASE {0};"'.format(self.db)
        extension = 'psql -U postgres -d {0} -c "CREATE EXTENSION postgis;"'.format(self.db)
        try:
            subprocess.check_call(create, shell=True)
            subprocess.check_call(extension, shell=True)
        except subprocess.CalledProcessError:
            logging.error('failed to create database with postgis enabled')




    def import_osm(self, project, style, osm, fpos):
        osm2pgsql = 'osm2pgsql -U postgres -d {0} -S {1} {2}'
        psql = 'psql -U postgres -d {0}'.format(db) 
        project = psql + '-f {0}'.format(project)
        rename = psql + '-c "ALTER TABLE planet_osm_line RENAME TO {0}; ALTER TABLE planet_osm_line_index RENAME TO {1};"'
        
        try:
            subprocess.check_call(osm2pgsql.format(db, style, osm), shell=True)
            subprocess.check_call(project, shell=True)       
            subprocess.check_call(rename.format('osm_filtered', 'osm_filtered_idx'), shell=True)       
        except subprocess.CalledProcessError:
            logging.error('failed import filtered osm into postgis')

        try:
            subprocess.check_call(osm2pgsql.format(db, style, fpos), shell=True)
            subprocess.check_call(project, shell=True)       
            subprocess.check_call(rename.format('fpos', 'fpos_idx'), shell=True)       
        except subprocess.CalledProcessError:
            logging.error('failed import false positives into postgis')
         

    def import_shape(self, urban_buf, co_fill):
        shp2pgsql = 'shp2pgsql -I -s 2913 -W LATIN1 {0} {1} | psql -U postgres -d {3}'
        
        try:
            subprocess.check_call(shp2pgsql.format(urban_buf, 'urban_buf', db), shell=True)
        except subprocess.CalledProcessError:
            logging.error('failed import urban_buffers into postgis')

        try:
            subprocess.check_call(shp2pgsql.format(co_fill, 'co_fill', db), shell=True)
        except subprocess.CalledProcessError:
            logging.error('failed import co_fill into postgis')


    def run(self):
        self.osmosis()
        #create_db()
        #import_osm()
        #import_shape()
    


if __name__ == '__main__':

    stype = sys.argv[1]
    diff = Diff(db, data_dir, osm_dir, shp_dir, util_dir, stype)
    diff.run()

    #if match == 'streets':
    #    osm_filtered = path.join(osm_dir, 'filtered_streets.osm')
    #elif match == 'trails':
    #    osm_filtered = path.join(osm_dir, 'filtered_trails.osm')
    #else:
    #    logging.error('incorrect argument, trails or streets only')
    #    sys.exit(2)

    #osmosis(street_tags, osm_filtered)
    #create_db(db)









#set parameters



#if trails
  #filter osm

#if streets
  #filter osm

#if no match
  #quit

#create database

#import osmfiltered
#import fpos
#import urban_buf
#import co_fill



