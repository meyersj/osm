import fiona
from shapely.geometry import shape, mapping, LineString
from rtree import index
import sys, os, codecs

sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

poly = '/home/jeff/trimet/shapely/test_data/poly.shp'
line = '/home/jeff/trimet/shapely/test_data/line.shp'
test_out = '/home/jeff/trimet/shapely/test_data/test_out.shp'



with fiona.open(line, 'r') as input:

  schema = input.schema
  crs = input.crs

  print schema
  idx = index.Index()

  data = {}
  for f in input:
    geom = shape(f['geometry'])
    fid = f['properties']['fid']
    data[fid] = geom
    idx.insert(fid, geom.bounds)


  for fid in data.keys():
    print str(fid) + '----'
    intersect = list(idx.intersection(data[fid].bounds))
    print intersect 
    geom = data[fid]
    for i in intersect:
      if data[i].intersects(geom):
        print 'True ' + str(i)
      else:
        print 'False ' + str(i) 
  

#left, bottom, right, top
"""
one = LineString([(0, 0), (1,1)])
one_bounds = (0.0, 0.0, 1.0, 1.0)
two = LineString([(1.5, 0.5),(2.5, 1.5)])
two_bounds = (1.5, 0.5, 2.5, 1.5)
three = LineString([(2, 0.5),(2, 1.5)])
three_bounds = (2.0,0.5,2.0,1.5)
four_bounds = (2.0, 1.0, 3.0, 2.0)
four = LineString([(2,2),(3,1)])

idx = index.Index()
idx.insert(1, one_bounds, one)
idx.insert(2, two_bounds, two)
idx.insert(3, three_bounds, three)
idx.insert(4, four_bounds, four)


for n in idx.intersection(three_bounds, objects=True):
  print n.area
"""



