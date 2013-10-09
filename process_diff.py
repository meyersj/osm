from shapely.geometry import mapping, shape
from shapely.ops import cascaded_union
from fiona import collection


rlis = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/rlis_trails.shp'
osm = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_trails.shp'
osm_buffer = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_buffer.shp'
osm_buffer_union = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_buffer_union.shp'
diff =  'P:/osm/rlis2osm_verify/7_county/scripts/test_data/diff.shp'


schema = { 'geometry': 'Polygon' , 'properties': {'name': 'str'} }

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

