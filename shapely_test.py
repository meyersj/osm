from fiona import collection
from fiona.crs import from_string
from shapely.geometry import shape, mapping, LineString, Polygon
from collections import OrderedDict

#-------------------------------------------------
import sys
from osgeo import osr

def prj2proj4(shapeprj_path):
  prj_file = open(shapeprj_path, 'r')
  prj_txt = prj_file.read()
  #srs = osr.SpatialReference()
  #srs.ImportFromESRI([prj_txt])
  #print 'Shape prj is: %s' % prj_txt
  #print 'WKT is: %s' % srs.ExportToWkt()
  #print 'Proj4 is: %s' % srs.ExportToProj4()
  #srs.AutoIdentifyEPSG()
  #print 'EPSG is: %s' % srs.GetAuthorityCode(None)
  return prj_txt
#--------------------------------------------------

#proj4 = prj2proj4('/home/jeff/trimet/shapely/test_data/rlis_trails.prj')
#print proj4

poly = '/home/jeff/trimet/shapely/test_data/poly.shp'
line = '/home/jeff/trimet/shapely/test_data/line.shp'
out_diff = '/home/jeff/trimet/shapely/test_data/out_v2.shp'


"""
poly = '/home/jeff/trimet/shapely/test_data/osm_buffer_dissolve.shp'
line = '/home/jeff/trimet/shapely/test_data/rlis_trails.shp'
out_diff = '/home/jeff/trimet/shapely/test_data/out_v2.shp'
"""
schema = { 'geometry': 'LineString' , 'properties': {'id': 'str'} }



with collection(poly, 'r') as input_poly:
  
  with collection(line, 'r') as input_line:
    difference = []

    for poly_f in input_poly:
      p_geo = shape(poly_f['geometry'])
      p_attr = poly_f['properties']
      print p_attr

      

      for line_f in input_line:
        l_geo = shape(line_f['geometry'])
        l_attr = line_f['properties']
        print l_attr
        l_attr.update(p_attr)
        print l_attr
        diff = l_geo.difference(p_geo)
        if not diff.is_empty:
          diff['properties'] = l_attr
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

