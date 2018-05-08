#! /usr/bin/env python
# -*- coding: latin-1 -*-
#

### Using elasticsearch-py ###
from cassandra.cluster import Cluster
from elasticsearch import Elasticsearch

import random
import argparse
import concurrent.futures
from cassandra import ConsistencyLevel
from cassandra.concurrent import execute_concurrent_with_args


## Script args and help
parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-s', action="store", dest="SCYLLA_IP", default="127.0.0.1")
parser.add_argument('-e', action="store", dest="ES_IP", default="127.0.0.1")
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
        res = es.search(index="catalog", doc_type="apparel", body={"query": {"match": {"group": "pants"}}, "size": 1000})

    if NUM_FILTERS == 'multiple':
        ## Search using multiple fields filter (color: 'white' AND sub_group: 'softshell')
        print("")
        print("## Searching for 'white softshell' in Elasticsearch (filter by color + sub_group)")
        res = es.search(index="catalog", doc_type="apparel", body={"query": {"bool": {"must": [{"match": {"color": "white"}}, {"match": {"sub_group": "softshell"}}]}}, "size": 1000})

    if NUM_FILTERS == 'none':
        ## Search with NO filters (match_all)
        print("")
        print("## Searching with NO filter = 'match_all' in Elasticsearch")
        res = es.search(index="catalog", doc_type="apparel", body={"query": {"match_all": {}}, "size": "1000"})

    print("")
    print("## %d documents returned" % res['hits']['total'])

    es_results = [doc['_id'] for doc in res['hits']['hits']]

    ## Connect to Scylla
    print("")
    print("## Connecting to Scylla")
    session = Cluster(SCYLLA_IP).connect()


    ## Prepared cql statement
    print("")
    print("## Preparing CQL statement")
    cql = "SELECT * FROM catalog.apparel WHERE sku=?"
    cql_prepared = session.prepare(cql)
    cql_prepared.consistency_level = ConsistencyLevel.ONE if random.random() < 0.2 else ConsistencyLevel.QUORUM


    ## Query Scylla
    print("")
    print("## Query Scylla using SKU/s returned from Elasticsearch")

    print("")
    print("## Final results from Scylla:")
    print("")
    for r in es_results:
        scylla_res = session.execute(cql_prepared, (r,))
        print("%s" % ([list(row) for row in scylla_res]))


    #for doc in res['hits']['hits']:

        ## Print all columns in Elasticsearch result set
        #print("SKU: %s | Color: %s | Size: %s | Brand: %s | Gender: %s | Group: %s | Sub_Group: %s" % (doc['_id'], doc['_source']['color'], doc['_source']['size'], doc['_source']['brand'], doc['_source']['gender'], doc['_source']['group'], doc['_source']['sub_group']))

        ## Print only the id (sku) in the result set
        #print("SKU: %s" % (doc['_id']))

    print("")

if __name__ == '__main__':
    query_es(opts.NUM_FILTERS)

