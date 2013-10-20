from fiona import open
from fiona.crs import from_string
from shapely.geometry import shape, mapping, Point, LineString, Polygon
from collections import OrderedDict
from shapely.ops import cascaded_union, linemerge
import sys, codecs
import pprint
sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

#-------------------------------------------------
#from osgeo import osr

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

"""
poly = '/home/jeff/trimet/shapely/test_data/poly.shp'
line = '/home/jeff/trimet/shapely/test_data/line.shp'
out_diff = '/home/jeff/trimet/shapely/test_data/out_v2.shp'
"""


osm = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_trails.shp'
rlis = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/rlis_trails.shp'
test_out = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_out.shp'
test_out2 = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_out2.shp'
test_merge = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_merge.shp'

def buffer(toBuffer, outFile, distance, dissolve):

  with open(toBuffer, 'r') as input:
    schema = input.schema
    crs = input.crs
    schema['geometry'] = 'Polygon'
    
    buf_features = []
    for f in input:   
      buf_features.append(( shape(f['geometry']).buffer(distance), f['properties'] ))
    
    if dissolve == True:
      buf_features = cascaded_union([geom for geom, prop in buf_features])
      schema = {'geometry':buf_features.geom_type, 'properties':{'fid':'int'}}
      buf_features = [(buf_features, {'fid':'1'})]
  
  for k, v in schema['properties'].items():
    if v[0:3] == 'str' and v[-3:] == '255':
      schema['properties'][k] = 'str:254'
 
 
  with open(outFile, 'w', 'ESRI Shapefile', crs=crs, schema=schema) as output:
    for geom, prop in buf_features: 
      output.write({'geometry': mapping(geom), 'properties':prop})


def dissolve_lines(toDissolve, outFile, attributes, multiPart):

  with open(toDissolve, 'r') as input:
    schema = input.schema
    crs = input.crs

    for k, v in schema['properties'].items():
      print k

    line_features = []
    for f in input:
      line_features.append(( shape(f['geometry']), f['properties'] ))
    
    #for geom, prop in line_features:
    #  print geom.geom_type

    if attributes == []:
      line_features = linemerge([geom for geom, prop in line_features])
      print len(line_features.geoms) 
      print line_features.geom_type
      if multiPart == True:
        schema = {'geometry':line_features.geom_type, 'properties':{'fid':'int'}}
        line_features = [(line_features, {'fid':1})] 
      
      else:
        schema = {'geometry':'LineString', 'properties':{'fid':'int'}}
        
        #print len(line_features.geoms)
        #merge([geom for geom, prop in line_features])
        single_lines = [geom for geom in line_features.geoms]
        line_features = []
        #print len(line_features.geoms)
        count = 1 
        for f in single_lines:
          line_features.append((f, {'fid':count} ))
          count += 1

 
  with open(outFile, 'w', 'ESRI Shapefile', crs=crs, schema=schema) as output:
    for geom, prop in line_features: 
      output.write({'geometry': mapping(geom), 'properties':prop})   
  

dissolve_lines(test_merge, test_out, [], False)


def test(outFile):

  schema = {'geometry':'Point', 'properties':{'id':'str:254'}}
 
  with open(outFile, 'w', 'ESRI Shapefile', schema, crs) as output:
    output.write({'geometry':  mapping(Point(0.0, 0.0)), 'properties':{'id':'test'}})
  
    print "success"


#test(test_out)

#buffer(rlis, test_out, 30, True)


"""
poly = '/home/jeff/trimet/shapely/test_data/osm_buffer_dissolve.shp'
line = '/home/jeff/trimet/shapely/test_data/rlis_trails.shp'
out_diff = '/home/jeff/trimet/shapely/test_data/out_v2.shp'

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
"""



