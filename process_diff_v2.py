import os, sys, arcpy
from arcpy import env


"""
arcpy scripts are so ugly :(

TODO: migrate arcpy functions to use shapely library

"""

#in_dir = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/'
#out_dir = 'P:/osm/rlis2osm_verify/7_county/scripts/test_data/output/'
out_dir = 'P:/osm/rlis2osm_verify/postgis/output/shapefiles/'

#sys.argv
in_rlis = sys.argv[1]
in_osm = sys.argv[2]
out_file = sys.argv[3]
method = sys.argv[4]

print in_rlis
print in_osm

#in_rlis = in_dir + 'rlis_trails.shp'
#in_osm = in_dir + 'osm_trails.shp'

temp_osm_buffer = out_dir + 'osm_trails_buffer.shp'
temp_rlis_dissolve = out_dir + 'rlis_dissolve.shp'
temp_box = out_dir + 'box.shp'
temp_box_buffer_union = out_dir + 'box_union.shp'
temp_rlis_needed = out_dir + 'rlis_needed.shp'

#sys.argv
out_rlis_final = out_dir + out_file

#env.workspace = in_dir
env.overwriteOutput = True


dissolve_trail_fields = ['systemname', 'abandoned', 'access','alt_name', 'bicycle', 
                         'cnstrctn', 'est_width', 'fee', 'foot', 'highway', 'hwy_abndnd','horse', 
                         'mtr_vhcle', 'mtb', 'name', 'operator', 'proposed', 'surface', 'wheelchair']

dissolve_street_fields = ['localid', 'oneway', 'name', 'highway', 'access', 'service', 'surface',
                          'pc_left', 'pc_right'] 

if method == 'trails':
  dissolve_fields = dissolve_trail_fields
elif method == 'streets':
  dissolve_fields = dissolve_street_fields


print "dissolve"
arcpy.Dissolve_management(in_rlis, temp_rlis_dissolve, dissolve_fields, '', "SINGLE_PART", "DISSOLVE_LINES")
print "buffer"
arcpy.Buffer_analysis(in_osm, temp_osm_buffer, '30 feet' , '', '', 'ALL', '')

desc = arcpy.Describe(in_osm)
extent = desc.extent
spatial_ref = desc.spatialReference

#create point features from extent of in_osm file
NW = arcpy.Point(extent.XMin - 5000, extent.YMax + 5000)
SW = arcpy.Point(extent.XMin - 5000, extent.YMin - 5000)
NE = arcpy.Point(extent.XMax + 5000, extent.YMax + 5000)
SE = arcpy.Point(extent.XMax + 5000, extent.YMin - 5000)

#create polygon bounding box of in_osm file
coord = arcpy.Array([NW, NE, SE, SW])
box = arcpy.Polygon(coord, spatial_ref) 
arcpy.CopyFeatures_management(box, temp_box)

print "union"
arcpy.Union_analysis([temp_osm_buffer, temp_box] , temp_box_buffer_union)
arcpy.MakeFeatureLayer_management (temp_box_buffer_union, 'intersect')
arcpy.SelectLayerByAttribute_management ('intersect', 'NEW_SELECTION', ' "fid_osm_tr" = -1 ')

print "intersect"
arcpy.Intersect_analysis ([temp_rlis_dissolve, 'intersect'], temp_rlis_needed, 'ALL', '', '')


#TODO converti temp_rlis_needed to single part features before calculating length and selecting out


print "add field"
arcpy.AddField_management(temp_rlis_needed, 'length', 'DOUBLE')
arcpy.CalculateField_management(temp_rlis_needed, 'length', "!SHAPE.LENGTH@FEET!", "PYTHON_9.3")
arcpy.MakeFeatureLayer_management (temp_rlis_needed, 'rlis_trails')
arcpy.SelectLayerByAttribute_management ('rlis_trails', 'NEW_SELECTION', ' "length" > 50 ')
arcpy.DeleteField_management('rlis_trails', 'FID_rlis_t')
arcpy.DeleteField_management('rlis_trails', 'FID_buffer')
arcpy.DeleteField_management('rlis_trails', 'FID_osm_tr')
arcpy.DeleteField_management('rlis_trails', 'Id')
arcpy.DeleteField_management('rlis_trails', 'FID_box')
arcpy.DeleteField_management('rlis_trails', 'Id_1')

print "export"
arcpy.CopyFeatures_management('rlis_trails', out_rlis_final)



arcpy.Delete_management(temp_osm_buffer)
arcpy.Delete_management(temp_rlis_dissolve)
arcpy.Delete_management(temp_box)
arcpy.Delete_management(temp_box_buffer_union)
arcpy.Delete_management(temp_rlis_needed)






