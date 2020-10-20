#! /usr/bin/env python3

import sys, http, urllib, xml.dom.minidom, urllib.request, time, json
from xml.dom.minidom import parse

def file2string( filename : str ) -> str :
    try :
        with open( filename, "r" ) as f :
            return f . read()
    except :
        return ""

def extract_search_id_from_xml( data : str ) -> str :
    try :
        DOM = xml.dom.minidom.parseString( data )
        coll = DOM.documentElement
        for c in coll.childNodes :
            if type( c ) is xml.dom.minidom.Element :
                if c . tagName == 'sid' :
                    return c . firstChild . data
        return "error 1"
    except Exception as ex:
        return "error"

def extract_status_from_xml( data : str ) -> ( str, str ) :
    status = "UNKNOWN"
    count = ""
    try :
        DOM = xml.dom.minidom.parseString( data )
        coll = DOM.documentElement
        c = coll.getElementsByTagName( "content" )
        if len( c ) > 0 :
            c0 = c[ 0 ]
            a = c0.getElementsByTagName( "s:dict" )
            if len( c ) > 0 :
                a0 = a[ 0 ]
                k = c0.getElementsByTagName( "s:key" )
                for q in k :
                    if q . getAttribute( 'name' ) == 'dispatchState' :
                        status = q . firstChild . data
                    if q . getAttribute( 'name' ) == 'eventCount' :
                        count = q . firstChild . data
    except :
        pass
    return ( status, count )

def extract_raw_from_json( data : str ) :
    res = []
    j = json.loads( data )
    for r in j[ 'results' ] :
        res.append( r[ '_raw' ] )
    return res

# returns the search-id
def create_search( bearer : str, search : str ) -> str :
    hdr = { 'Authorization' : "Bearer " + bearer }
    domain = "splunkapi.ncbi.nlm.nih.gov"
    path = "/services/search/jobs/"
    data = urllib.parse.urlencode( { 'search' : search } )
    conn = http.client.HTTPSConnection( domain )
    conn . request( 'POST', path, data, hdr )
    req = conn . getresponse()
    return extract_search_id_from_xml( req.read() )

def get_search_status( bearer : str, sid : str ) -> ( str, str ) :
    hdr = { 'Authorization' : "Bearer " + bearer }
    domain = "splunkapi.ncbi.nlm.nih.gov"
    path = "/services/search/jobs/" + sid
    conn = http.client.HTTPSConnection( domain )
    conn . request( 'GET', path, None, hdr )
    req = conn . getresponse()
    return extract_status_from_xml( req.read() )

def get_search_results( bearer : str, sid : str, offset : int, count : int ) -> str :
    hdr = { 'Authorization' : "Bearer " + bearer }
    domain = "splunkapi.ncbi.nlm.nih.gov"
    data = urllib.parse.urlencode( { "count" : count, "offset" : offset, "output_mode" : "json" } )
    path = "/services/search/jobs/" + sid + "/results?" + data
    conn = http.client.HTTPSConnection( domain )
    conn . request( 'GET', path, None, hdr )
    req = conn . getresponse()
    return req.read().decode()

def wait_for_done( bearer : str, sid : str ) -> ( str, str ) :
    x = 10
    status = 'UNKNOWN'
    count = ""
    while x > 0 :
        status, count = get_search_status( bearer, sid )
        if status == 'DONE' :
            return ( status, count )
        time.sleep( 0.5 )
        x -= 1
    return ( status, count )

search="search index=unix sourcetype=syslog host=cloudian-node* S3REQ bucketOwnerUserId=trace earliest=-1m"
bearer = file2string( "bearer.txt" )

sid = create_search( bearer, search )
status, count = wait_for_done( bearer, sid )

#print( "status="+status )
#print( "count="+count )
row_count = int( count )

if status == 'DONE' and row_count > 0 :
# todo loop in batches of x rows until count is reached
    results = get_search_results( bearer, sid, 3, 20 )
    a = extract_raw_from_json( results )
    for line in a :
        print( line )