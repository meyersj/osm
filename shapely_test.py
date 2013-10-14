from fiona import collection
from shapely.geometry import shape, mapping, LineString, Polygon
from collections import OrderedDict

poly = '/home/jeff/trimet/shapely/test_data/osm_buffer_dissolve.shp'
line = '/home/jeff/trimet/shapely/test_data/rlis_trails.shp'
out_diff = '/home/jeff/trimet/shapely/test_data/out_v2.shp'

schema = { 'geometry': 'LineString' , 'properties': {'id': 'str'} }

with collection(poly, 'r') as input_poly:
  with collection(line, 'r') as input_line:

    difference = []

    for poly_f in input_poly:
      p_geo = shape(poly_f['geometry'])

      for line_f in input_line:
        l_geo = shape(line_f['geometry'])
        diff = l_geo.difference(p_geo)
        if not diff.is_empty:
          difference.append(diff)    

with collection(out_diff, 'w', 'ESRI Shapefile', schema) as output:
  count = 1
  for o_line in difference:
    output.write({
      'properties': {
        'id':count
      },
      'geometry': mapping(o_line)
    })

