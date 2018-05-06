#! /usr/bin/env python
# -*- coding: latin-1 -*-
#

### Using elasticsearch-py ###
import csv
from cassandra.cluster import Cluster
from elasticsearch import Elasticsearch

import random
import argparse
import concurrent.futures
from cassandra import ConsistencyLevel
from cassandra.concurrent import execute_concurrent_with_args


## Script args and Help
parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-s', action="store", dest="SCYLLA_IP", default="127.0.0.1")
parser.add_argument('-e', action="store", dest="ES_IP", default="127.0.0.1")

opts = parser.parse_args()

SCYLLA_IP = opts.SCYLLA_IP.split(',')
ES_IP = opts.ES_IP.split(',')


## Define KS + Table
create_ks = "CREATE KEYSPACE IF NOT EXISTS catalog WITH replication = {'class' : 'SimpleStrategy', 'replication_factor' : 3};"
create_t1 = "CREATE TABLE IF NOT EXISTS catalog.apparel (sku text, brand text, group text, sub_group text, color text, size text, gender text, PRIMARY KEY ((sku),color,size));"


## Loading the data
def load_data(filename):
    data = []
    headers = []
    with open(filename, "r") as f:
        reader = csv.reader(f)
        headers = next(reader) # read the headers line

        for l in reader:
            doc = {}
            for i in range(0, len(l)):
                doc[headers[i].lower()] = l[i]

            data.append(doc)

    return headers, data


## Insert the data
def insert_data(headers, data):
    ## Connect to Scylla cluster and create schema
    # session = cassandra.cluster.Cluster(SCYLLA_IP).connect()
    print("")
    print("## Connecting to Scylla cluster -> Creating schema")
    session = Cluster(SCYLLA_IP).connect()
    session.execute(create_ks)
    session.execute(create_t1)

    ## Connect to Elasticsearch
    print ("")
    print ("## Connecting to Elasticsearch -> Creating 'Catalog' index")
    es = Elasticsearch(ES_IP)
    
    ## Create Elasticsearch index. Ignore 400 = IF NOT EXIST
    es.indices.create(index="catalog", ignore=400)

    ## Non-prepared CQL statement
    #cql = "INSERT INTO catalog.apparel(sku,brand,group,sub_group,color,size,gender) VALUES(%(sku)s,%(brand)s,%(group)s,%(sub_group)s,%(color)s,%(size)s,%(gender)s)"

    ## Prepared CQL statement
    print("")
    print("## Preparing CQL statement")
    cql = "INSERT INTO catalog.apparel (sku,brand,group,sub_group,color,size,gender) VALUES (?,?,?,?,?,?,?) using TIMESTAMP ?"
    cql_prepared = session.prepare(cql)
    cql_prepared.consistency_level = ConsistencyLevel.ONE if random.random() < 0.2 else ConsistencyLevel.QUORUM

    print("")
    print("## Insert csv content into Scylla and Elasticsearch")


    for d in data: 
        # See if we need to add code to wait for the ack. This should be synchronous.
        # Also, might need to switch to prepared statements to set the consistency level for sync requests.
        session.execute(cql_prepared, d)

        res = es.index(index="catalog", doc_type="apparel", id=d["sku"], body=d)

    ## After all the inserts, make a refresh, just in case
    print("")
    print("## Inserts completed, refreshing index")
    es.indices.refresh(index="catalog")

    print("")


if __name__ == "__main__":
    headers, data = load_data("./catalog.csv")
    insert_data(headers, data)
