import fiona
from shapely.geometry import shape, mapping, Point, LineString, Polygon
from collections import OrderedDict
from shapely.ops import cascaded_union, linemerge
import sys, codecs, pprint
from rtree import index
sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

poly = '/home/jeff/trimet/shapely/test_data/poly.shp'
line = '/home/jeff/trimet/shapely/test_data/line.shp'
test_out_dir = '/home/jeff/trimet/shapely/test_data/'
rlis_trails = '/home/jeff/trimet/shapely/test_data/rlis_trails.shp'



"""
osm = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/osm_trails.shp'
rlis = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/rlis_trails.shp'
test_out = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_out.shp'
test_out2 = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_out2.shp'
test_merge = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/test_merge.shp'
"""

class geo:


  def buffer(self, toBuffer, outFile, distance, dissolve):

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
    #works without this block in source compiled verions 
    #--------------------------------------------------
    for k, v in schema['properties'].items():
      if v[0:3] == 'str' and v[-3:] == '255':
        schema['properties'][k] = 'str:254'
    #--------------------------------------------------
   
    with fiona.open(outFile, 'w', 'ESRI Shapefile', crs=crs, schema=schema) as output:
      for geom, prop in buf_features: 
        output.write({'geometry': mapping(geom), 'properties':prop})


  def __ifDisjoint(self, inFeature, features):
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
        if inFeature.equals(n.object) is False and inFeature.disjoint(n.object) is False:
          return False

    return True

  def __unionIntersecting(self, features, idx, disjointFeatures):

    if not features:
      return disjointFeatures

    else:
      index = features.iterkeys().next()
      f = features[index][0]
      f_prop = features[index][1]
      
      if self.__ifDisjoint(f, [features[i][0] for i in features.keys()]):
        idx.delete(index, features[index][0].bounds)
        disjointFeatures.append(features[index])
        del features[index]
        return self.__unionIntersecting(features, idx, disjointFeatures) 
      else:
        intersecting_bounds = list(idx.intersection(f.bounds, objects=True))
        
        for n in intersecting_bounds:
          if index != n.id and (f.disjoint(n.object[0]) is False):
            idx.delete(index, f.bounds)
            if f.geom_type[0:4] == 'Mult' or n.object[0].geom_type[0:4] == 'Mult':
              f = f.union(n.object[0])
            else:
              f = linemerge([f, n.object[0]])
            del features[index]
            del features[n.id]
            idx.delete(n.id, n.object[0].bounds)
            idx.insert(index, f.bounds, f)
            features[index] = [f, f_prop]

        return self.__unionIntersecting(features, idx, disjointFeatures)

  def dissolve_lines(self, toDissolve, outFile, attributes, multiPart):

    with fiona.open(toDissolve, 'r') as input:
      schema = input.schema
      crs = input.crs

      features = {}
      for i, f in enumerate(input):
        features[i] = [shape(f['geometry']), f['properties']]
      
      if attributes:
      #TODO test this if block to make it dissolves features properly by attributes param

        for attr in schema['properties'].keys():
          if attr not in attributes:
            del schema['properties'][attr]

        attr_sets = {}
        for i in features.keys():
          prop_list = []
          for key in features[i][1].keys():
            if key in attributes:
              prop_list.append(features[i][1][key])
          
          attr_sets[tuple(prop_list)] = []
          features[i].append(tuple(prop_list))

        for i in features.keys():
          attr_sets[features[i][2]].append(features[i])
          del features[i][2]
        
        disjointFeatures = []
        for key in attr_sets.keys():
          for item in attr_sets[key]:
            idx = index.Index()
            for i in features.keys():
              idx.insert(i, features[i][0].bounds, features[i])
            disjointFeatures_partial = []
            disjointFeatures = disjointFeatures + self.__unionIntersecting(features, idx, disjointFeatures_partial)
         
        for feature in disjointFeatures:
           for attr in feature[1].keys():
             if attr not in attributes:
               del feature[1][attr]
    
        dissolveFeatures = disjointFeatures

      #no attributes specified, dissolve all features
      else:
        #if multiPart is True all features will be dissolve 
        if multiPart is True:
          features = linemerge([geom for geom, prop in features.values()])
          schema = {'geometry':features.geom_type, 'properties':{'fid':'int'}}
          dissolveFeatures = [(features, {'fid':1})] 
        #if multiPart is False dissolve all features that are not disjoint 
        elif multiPart is False:
          schema = {'geometry':'MultiLineString', 'properties':{'fid':'int'}}

          idx = index.Index()
          for i in features.keys():
            idx.insert(i, features[i][0].bounds, features[i])

          disjointFeatures = []
          self.__unionIntersecting(features, idx, disjointFeatures)

          dissolveFeatures = []          
          count = 0
          for geom, prop in disjointFeatures:
            dissolveFeatures.append((geom, {'fid':count}))
            count += 1

    with fiona.open(outFile, 'w', 'ESRI Shapefile', crs=crs, schema=schema) as output:
      for geom, prop in dissolveFeatures:
        output.write({'geometry': mapping(geom), 'properties':prop})   


if __name__ == '__main__':
  my_geo = geo()
  my_geo.dissolve_lines(rlis_trails, test_out_dir + 'rlis_all_multi_name.shp', ['systemname'], True)

