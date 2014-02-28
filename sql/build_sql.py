import pystache, sys

def qualify(attrs, qual):
    new_attr = '{0}.{1}'
    qual_attrs = []
    for attr in attrs:
        qual_attrs.append(new_attr.format(qual, attr))
    return qual_attrs

def build_attr(attrs, end_comma=True):
    query = ''
    for attr in attrs:
        query = query + attr + ','
    query = query[:-1]
    if end_comma:
        query = query + ','
    return query

def build_diff_sql(sql_in, sql_out, attrs_file):
    attrs = None

    try:
        with open(attrs_file, 'r') as fields:
            attrs = fields.read().splitlines()
        jurisd = build_attr(qualify(attrs, 'jurisd'))   
        sq = build_attr(qualify(attrs, 'sq'))   
        diff = build_attr(qualify(attrs, 'diff'))    
        diff_end = build_attr(qualify(attrs, 'diff'), False)    
        with open(sql_in, 'r') as sql:
            data = sql.read()
            data = pystache.render(data, {'jurisd':jurisd,
                                          'sq':sq,
                                          'diff':diff,
                                          'diff_end':diff_end}) 
        with open(sql_out, 'wb') as sql:
            data = data.replace('&qout;', '"')
            sql.write(data)
    except:
        return False        
    return True


def build_fpos_sql(sql_in, sql_out, attrs_file):
    attrs = None

    try:
        with open(attrs_file, 'r') as fields:
            attrs = fields.read().splitlines()
        jurisd = build_attr(qualify(attrs, 'jurisd'))   
        with open(sql_in, 'r') as sql:
            data = sql.read()
            data = pystache.render(data, {'jurisd':jurisd})
        with open(sql_out, 'wb') as sql:
            data = data.replace('&qout;', '"')
            sql.write(data)
    except:
        return False        
    return True

def build_split_sql(sql_out, counties_file, name):
    data = "BEGIN;\n{0}\nCOMMIT;"
    queries = ""
    create = """
CREATE TABLE {{data}}_diff_{{county}} AS
(
  SELECT diff.*
  FROM {{data}}_diff AS diff
  JOIN co_fill AS co
  ON ST_Intersects(diff.geom, co.geom)
  WHERE co.county = '{{county}}'
);\n"""
 
    with open(counties_file, 'r') as cf:
        counties = cf.read().splitlines()
    for county in counties:
        queries = queries + pystache.render(create, {'data':name, 'county':county[0:4]})
    with open(sql_out, 'wb') as sql:
        sql.write(data.format(queries))

if __name__ == '__main__':
    #counties = ['washington', 'multnomah', 'clackamas', 'yamhill']

    #build_split_sql('create_test.sql','counties.txt','rlis_streets')

    schema = sys.argv[1]
    first = sys.argv[2]
    second = sys.argv[3]
    third = sys.argv[4]


    result = None 
    if schema == 'diff':
        result = build_diff_sql(first, second, third)
    elif schema == 'fpos':
        result = build_fpos_sql(first, second, third)
    elif schema == 'split':
        result = build_split_sql(first, second, third)
    
    if result:
        print "success"
    else:
        print "fail"

    #test_in = 'generate_diff_template.sql'
    #test_out = 'generate_diff.sql'
    #attrs_file = 'G:/PUBLIC/OpenStreetMap/data/OSM_update/utilities/rlis_bike_fields.txt'
    #attrs = ['oneway','direction','name','description','highway','access','service','surface','pc_left','pc_right']
    
    #if build_sql(template, output, fields):
    #    print 'success'
    #else:
    #    print 'fail'
