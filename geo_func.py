import fiona
from shapely.geometry import shape, mapping, Point, LineString, Polygon
from collections import OrderedDict
from shapely.ops import cascaded_union, linemerge
import sys, codecs, pprint
from rtree import index
sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

poly = '/home/jeff/trimet/shapely/test_data/poly.shp'
line = '/home/jeff/trimet/shapely/test_data/line.shp'
test_out = '/home/jeff/trimet/shapely/test_data/test_out.shp'

"""
osm = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_trails.shp'
rlis = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/rlis_trails.shp'
test_out = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_out.shp'
test_out2 = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_out2.shp'
test_merge = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_merge.shp'
"""

def buffer(toBuffer, outFile, distance, dissolve):

  with fiona.open(toBuffer, 'r') as input:
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
 

  #in windows compiled shapely library python crashes if str has 255 characters
  #works without this function in source compiled verions 
  for k, v in schema['properties'].items():
    if v[0:3] == 'str' and v[-3:] == '255':
      schema['properties'][k] = 'str:254'
 
 
  with fiona.open(outFile, 'w', 'ESRI Shapefile', crs=crs, schema=schema) as output:
    for geom, prop in buf_features: 
      output.write({'geometry': mapping(geom), 'properties':prop})



def ifDisjoint(infeature, features):
  # build index with bounding box of inFeature and features list
  idx = index.Index()
  idx.insert(0, inFeature.bounds, inFeature)

  for i, f in enumerate(features):
    idx.insert(i+1, f.bounds, f)

  # create list of features with bbox that intersect inFeatures bbox
  # if inFeature is disjoint from features list return True 
  intersect = list(idx.intersection(inFeature.bounds, objects=True))
    if len(intersect) > 1:  
      for n in intersect:
        if f.equals(n.object) is False and inFeature.intersects(n.object):
          return False  

  return True



#TODO not going to compile, adding and removing from list while iterating through it
def unionIntersecting(features, disjointFeatures, idx):

  if features is False:
    return disjointFeatures

  for f in features:
    box_intersects = list(idx.intersects(f.bounds, objects=True))

    for n in box_intersects:
      if f.equals(n.object) is False and f.intersects(n.object):
        f = f.union(n.object)
        idx.delete(n.id, n.bounds)
        features.pop(n.id)
        idx.insert(n.id, f.bounds, f)
        features[n.id] = f

    if ifDisjoint(f, features):
      disjointFeautures[n.id] = f
      features.pop(n.id) 
 
  return unionIntersecting(features, disjointFeatures, idx)
 
  



 






def dissolve_lines(toDissolve, outFile, attributes, multiPart):

  with fiona.open(toDissolve, 'r') as input:
    schema = input.schema
    crs = input.crs

    for k, v in schema['properties'].items():
      print k
    
    line_features = []
    for i, f in enumerate(input):
      features[i] = (shape(f['geometry']), f['properties'])

    if attributes:
      print "not empty"
    
    #no attributes specified, dissolve all features
    else:
      #if multiPart is True all features will be dissolve 
      if multiPart is True:
        features = linemerge([geom for geom, prop in features.values()])
        schema = {'geometry':features.geom_type, 'properties':{'fid':'int'}}
        features = [(features, {'fid':1})] 
     #if multiPart is False dissolve all features that are not disjoint 
     elif multiPart is False:


       idx = index.Index()
       for i in features.keys():
         idx.insert(i, features[i][0].bounds, features[i])  

        
       



       #disjoint = ifDisjoint([geom for geom, prop in line_features])

      

  """
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
  """
  """
  with fiona.open(outFile, 'w', 'ESRI Shapefile', crs=crs, schema=schema) as output:
    for geom, prop in line_features: 
      output.write({'geometry': mapping(geom), 'properties':prop})   
  """

def test(outFile):

  schema = {'geometry':'Point', 'properties':{'id':'str:254'}}
 
  with fiona.open(outFile, 'w', 'ESRI Shapefile', schema, crs) as output:
    output.write({'geometry':  mapping(Point(0.0, 0.0)), 'properties':{'id':'test'}})
  
    print "success"

#test(test_out)
#buffer(rlis, test_out, 30, True)

test_attr = ['name', 'systemname', 'est_width', 'access', 
             'surface', 'highway', 'foot', 'bicycle']


dissolve_lines(line, test_out, [], False)
