from shapely.geometry import mapping, shape, Polygon
from shapely.ops import cascaded_union
from fiona import collection
import ast

rlis = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/rlis_trails.shp'
osm = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_trails.shp'
osm_buffer = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_buffer.shp'
osm_buffer_union = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_buffer_union.shp'
diff =  'P:/osm/rlis2osm_verify/7_county/scripts/test_data/diff.shp'
osm_buffer_union_split = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_buffer_union_split.shp'

schema = { 'geometry': 'Polygon' , 'properties': {'name': 'str'} }

"""
with collection(osm, 'r') as input:
  for line in input:
    print shape(line['geometry'])


  with collection(osm_buffer, 'w', 'ESRI Shapefile', schema) as output:
    for line in input:
      output.write({
	'properties': {
	  'name': 'test'
	 },
        'geometry': mapping(shape(line['geometry']).buffer(30))
      })

with collection(osm_buffer, 'r') as input:
  schema = input.schema.copy()
  with collection(osm_buffer_union, 'w', 'ESRI Shapefile', schema) as output:
    shapes = []
    for f in input:
      shapes.append(shape(f['geometry']))
    merged = cascaded_union(shapes)
    output.write({
      'properties': {
        'name': 'Buffer Area'
      },
      'geometry': mapping(merged)
    })

with collection(osm_buffer, 'r') as input:
  schema = input.schema.copy()
  with collection(osm_buffer_union, 'w', 'ESRI Shapefile', schema) as output:
    shapes = []
    for f in input:
      shapes.append(shape(f['geometry']))
    merged = cascaded_union(shapes)
    output.write({
      'properties': {
        'name': 'Buffer Area'
      },
      'geometry': mapping(merged)
    })
"""


polygons = []

count = 1
with collection(osm_buffer_union, 'r') as input:
  for polygon in input:
    string = str(shape(polygon['geometry']))

    #print string
    coord = string.split('(', 1)[1].split(',')
    for item in coord:
      print item
    #print coord
 
    """
    #f_polygon = {}
    for f in coord:
      end = False
      f = f.strip()
      if f[0] == '{' or f[0] == '('i:
        f = f[1:]
      elif f[-1] == '}':
        f = f[0:-1]
        end = True
 
      f = f.split(' ')
      x = float(f[0])
      y = float(f[1])
      pair = x , y
      if end == False:
        f_polygon['pair'] =
      else:
        f_polygon.append(pair)
        polygons.append(f_polygon)
        f_polygon = []
    """
    #print polygons
    #polygons = ast.literal_eval(polygons)
  
    #for polygon in polygons:
      #print polygon
     
  with collection(osm_buffer_union_split, 'w', 'ESRI Shapefile', schema) as output:
    for poly in polygons:
      f = Polygon(poly)
      #print shape(f)
      #output.write({
	#'properties': {
	#  'name': 'test'
	# },
        #'geometry': mapping(shape(f))
      #})
"""
with collection(rlis, 'r') as input_rlis:
  with collection(osm_buffer_union) as input_osm

  schema = input_rlis.schema.copy()
  with collection(diff, 'w', 'ESRI Shapefile', schema) as output:
    diffshapes = []
    for f in input:
      shapes.append(shape(f['geometry']))
    merged = cascaded_union(shapes)
    output.write({
      'properties': {
        'name': 'Buffer Area'
      },
      'geometry': mapping(merged)
    })

"""

