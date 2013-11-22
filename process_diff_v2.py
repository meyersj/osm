import os, sys, codecs, arcpy
from arcpy import env
#set standard output to print utf-8 characters
sys.stdout = codecs.getwriter('utf-8')(sys.stdout)

#sys.argv
in_jurisd = sys.argv[1]
in_osm = sys.argv[2]
out_file = sys.argv[3]
out_dir = sys.argv[4]
dissolve_file = sys.argv[5]
util_dir = 'G:/PUBLIC/OpenStreetMap/data/OSM_update/utilities/'
in_regions = util_dir + 'oregon_urban_buffers.shp'
dissolve_fields = ''

try:
    dissolve_fields = [field.strip() for field in open(dissolve_file, 'r')]
except IOError:
    print "error opening " + dissolve_file

temp_regions_overlay = out_dir + 'regions_overlay.shp'
temp_osm_buffer = out_dir + 'osm_buffer.shp'
temp_jurisd_dissolve = out_dir + 'jurisd_dissolve.shp'
temp_box = out_dir + 'box.shp'
temp_box_buffer_union = out_dir + 'box_union.shp'
temp_jurisd_needed = out_dir + 'jurisd_needed.shp'
temp_jurisd_needed_single = out_dir + 'jurisd_needed_single.shp'

#sys.argv
out_jurisd_final = out_dir + out_file

#env.workspace = in_dir
env.overwriteOutput = True

print "dissolve"
arcpy.Dissolve_management(in_jurisd, temp_jurisd_dissolve, dissolve_fields, '', "SINGLE_PART", "DISSOLVE_LINES")
print "region overlay then buffer"
arcpy.Intersect_analysis([in_regions, in_osm], temp_regions_overlay, '', '', '')
arcpy.Buffer_analysis(temp_regions_overlay, temp_osm_buffer, 'buffer' , '', '', 'ALL', '')

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
arcpy.MakeFeatureLayer_management(temp_box_buffer_union, 'intersect')
arcpy.SelectLayerByAttribute_management ('intersect', 'NEW_SELECTION', ' "FID_osm_bu" = -1 ')

print "intersect"
arcpy.Intersect_analysis([temp_jurisd_dissolve, 'intersect'], temp_jurisd_needed, 'ALL', '', '')

print "multipart to singlepart"
arcpy.MultipartToSinglepart_management(temp_jurisd_needed, temp_jurisd_needed_single)

print "add and query length field"
arcpy.AddField_management(temp_jurisd_needed_single, 'length', 'DOUBLE')
arcpy.CalculateField_management(temp_jurisd_needed_single, 'length', "!SHAPE.LENGTH@FEET!", "PYTHON_9.3")
arcpy.MakeFeatureLayer_management (temp_jurisd_needed_single, 'jurisd_trails')
arcpy.SelectLayerByAttribute_management ('jurisd_trails', 'NEW_SELECTION', ' "length" > 50 ')
arcpy.DeleteField_management('jurisd_trails', 'FID_jurisd_t')
arcpy.DeleteField_management('jurisd_trails', 'FID_buffer')
arcpy.DeleteField_management('jurisd_trails', 'FID_osm_tr')
arcpy.DeleteField_management('jurisd_trails', 'Id')
arcpy.DeleteField_management('jurisd_trails', 'FID_box')
arcpy.DeleteField_management('jurisd_trails', 'Id_1')

print "export"
arcpy.CopyFeatures_management('jurisd_trails', out_jurisd_final)

print "cleaning up"
arcpy.Delete_management(temp_osm_buffer)
arcpy.Delete_management(temp_regions_overlay)
arcpy.Delete_management(temp_jurisd_dissolve)
arcpy.Delete_management(temp_box)
arcpy.Delete_management(temp_box_buffer_union)
arcpy.Delete_management(temp_jurisd_needed)
arcpy.Delete_management(temp_jurisd_needed_single)
