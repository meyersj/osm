from fiona import collection
from shapely.geometry import shape, mapping, Polygon, LineString
import sys, codecs

sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

co_fill = 'G:/Rlis/BOUNDARY/co_fill.shp'
diff = 'P:/osm/rlis2osm_verify/postgis/output/shapefiles/rlis_streets_diff_single_large.shp'
mult_diff = 'P:/osm/rlis2osm_verify/postgis/output/shapefiles/mult_diff.shp'
clack_diff = 'P:/osm/rlis2osm_verify/postgis/output/shapefiles/clack_diff.shp'
wash_diff = 'P:/osm/rlis2osm_verify/postgis/output/shapefiles/wash_diff.shp'

counties_name = {'Multnomah':mult_diff,'Clackamas':clack_diff, 'Washington':wash_diff}
counties_geom = {}

with collection(co_fill, 'r') as counties:

  for county in counties:
    name = county['properties']['COUNTY']
    
    if name in counties_name:
      counties_geom[name] = county['geometry']



streets_dict = {'Multnomah':[], 'Clackamas':[], 'Washington':[]}


for co_name, co_feature in counties_geom.iteritems():
  with collection(diff, 'r') as streets:
    streets_schema = streets.schema.copy() 
    co_geom = shape(co_feature)
    
    for street in streets:
      if shape(street['geometry']).intersects(co_geom) == True:
        streets_dict[co_name].append(street)





for name, output in counties_name.iteritems():

  print name
  print output

  with collection(output, 'w', 'ESRI Shapefile', streets_schema) as streets_out:

    for street in streets_dict[name]:
  
      streets_out.write({
        'properties':street['properties'],
        'geometry':mapping(shape(street['geometry']))
      })

   



