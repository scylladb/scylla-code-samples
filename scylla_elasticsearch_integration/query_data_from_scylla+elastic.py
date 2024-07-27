#! /usr/bin/env python
# -*- coding: latin-1 -*-
#

### Using elasticsearch-py ###
from cassandra.cluster import Cluster
from cassandra import ConsistencyLevel
from elasticsearch import Elasticsearch

import random
import argparse

## Script args and Help
parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-s', action="store", dest="SCYLLA_IP", default="localhost")
parser.add_argument('-e', action="store", dest="ES_IP", default="http://localhost:9200")
parser.add_argument('-n', action="store", dest="NUM_FILTERS", default="multiple")

opts = parser.parse_args()

SCYLLA_IP = opts.SCYLLA_IP.split(',')
ES_IP = opts.ES_IP.split(',')

def query_es(NUM_FILTERS):

    ## Connect to Elasticsearch
    print("")
    print("## Connecting to Elasticsearch")
    es = Elasticsearch(ES_IP)
    
    if NUM_FILTERS == 'single':
        ## Search using single field filter (group: 'pants')
        print("")
        print("## Searching for 'pants' in Elasticsearch (filter by group)")
        res = es.search(index="catalog", body={"query": {"match": {"group": "pants"}}, "size": 1000})
        
    if NUM_FILTERS == 'multiple':
        ## Search using multiple fields filter (color: 'white' AND sub_group: 'softshell')
        print("")
        print("## Searching for 'white softshell' in Elasticsearch (filter by color + sub_group)")
        res = es.search(index="catalog", body={"query": {"bool": {"must": [{"match": {"color": "white"}}, {"match": {"sub_group": "softshell"}}]}}, "size": 1000})
    
    if NUM_FILTERS == 'none':
        ## Search with NO filters (match_all)
        print("")
        print("## Searching with NO filter = 'match_all' in Elasticsearch")
        res = es.search(index="catalog", body={"query": {"match_all": {}}, "size": "1000"})
    
    print("")
    print(f"## {res['hits']['total']['value']} documents returned")
    
    es_results = [doc['_id'] for doc in res['hits']['hits']]
    
    print("## Connecting to Scylla")
    session = Cluster(SCYLLA_IP).connect()
    
    ## Prepare the CQL query
    cql = "SELECT * FROM catalog.apparel WHERE sku = ?"
    cql_prepared = session.prepare(cql)
    cql_prepared.consistency_level = ConsistencyLevel.ONE if random.random() < 0.2 else ConsistencyLevel.QUORUM
    
    ## Query Scylla
    print("## Query Scylla using SKU/s returned from Elasticsearch")
    print("## Final results from Scylla:")
    
    for r in es_results:
        scylla_res = session.execute(cql_prepared, (r,))
        
        ## Print all columns in Scylla result set
        print([list(row) for row in scylla_res])
    
    for doc in res['hits']['hits']:

        ## Print all columns in Elasticsearch result set
        print(f"SKU: {doc['_id']} | Color: {doc['_source']['color']} | Size: {doc['_source']['size']} | Brand: {doc['_source']['brand']} | Gender: {doc['_source']['gender']} | Group: {doc['_source']['group']} | Sub_Group: {doc['_source']['sub_group']}")

        ## Print only the id (sku) in the result set
        print("SKU: %s" % (doc['_id']))
        
if __name__ == '__main__':
    query_es(opts.NUM_FILTERS)