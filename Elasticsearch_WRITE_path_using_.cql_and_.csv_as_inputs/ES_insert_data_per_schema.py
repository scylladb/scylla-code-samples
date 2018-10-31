#!/usr/bin/env python
# -*- coding: latin-1 -*-
#

### Using elasticsearch-py ###
import os
import re
import csv
from datetime import datetime
from cassandra.cluster import Cluster
from elasticsearch import Elasticsearch

import random
import argparse
import concurrent.futures
from cassandra import ConsistencyLevel
from cassandra.concurrent import execute_concurrent_with_args


## Script args and Help
parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-e', action="store", dest="ES_IP", default="127.0.0.1")
parser.add_argument('-c', action="store", dest="csv_file_name", default=None)
parser.add_argument('-s', action="store", dest="cql_schema_file_name", default=None)
parser.add_argument('-i', action="store", dest="ignore_cql_schema", default=True)

opts = parser.parse_args()

ES_IP = opts.ES_IP.split(',')



def get_primary_key_fields(schema_filename, csv_filename, ignore_cql_schema):
    if schema_filename is None and csv_filename is None:
        print("")
        raise ValueError("Both schema file (.cql) and data file (.csv) are missing - Exit script")

    # If we didn't get a schema file but did get a csv file, or ignoring cql schema (default),
    # then select the first column from the csv as the key to be used as the ES id field
    if schema_filename is None or ignore_cql_schema is True:
        print("")
        print("## No schema provided / Ignoring schema -> using column1 from csv as 'id' for Elasticsearch index")
        with open(csv_filename, "r") as f:
            reader = csv.reader(f)
            headers_row = next(reader)
            return [headers_row[0]]
    else:
        with open(schema_filename, "r") as f:
            schema_file = f.read()

            # Check for compound PK i.e.   PRIMARY KEY ((col1,col2),col3)
            print("")
            print("## Check schema ({0}) for compound primary key to be used as index id".format(schema_filename))
            m = re.search(r"PRIMARY KEY \(\((.+?)\)", schema_file, re.I)
            if m:
                keys = m.group(1).split(",")
                return [k.strip() for k in keys]
	    
            # We didn't find a compound PK, try checking for a regular PK i.e.   PRIMARY KEY (col1,col2,col3)
            print("")
            print("## Did not find a compound primary key, checking for regular primary key to be used as index id")
            m = re.search(r"PRIMARY KEY \((.+)\)", schema_file, re.I)
            if m:
                keys = m.group(1).split(",")
                return [keys[0]]
        return []

def get_index_name(filename):
    return os.path.splitext(os.path.basename(filename))[0]

def get_headers(reader):
    headers = next(reader)

    headers_index_mapping = {}
    for i in range(0, len(headers)):
        headers_index_mapping[headers[i]] = i

    return headers, headers_index_mapping

def get_es_id(row, headers, headers_index_mapping, keys):
    es_id = []
    for k in keys:
        i = headers_index_mapping[k]
        es_id.append(row[i])

    return "-".join(es_id)

def get_row_data(row, headers):
    data = {}
    for i in range(0, len(row)):
        val = None
        try:
            val = int(row[i])
        except ValueError:
            val = row[i]
            
        data[headers[i]] = row[i]
    return data

## Insert the data
def insert_data(csv_filename, keys):
    ## Connect to ES

    index_name = get_index_name(csv_filename)

    # Connecting to ES -> Creating index, if not exist
    print("")
    print("## Connecting to ES -> Creating '{0}' index, if not exist".format(index_name))
    es = Elasticsearch(ES_IP)
    # Create ES index. Ignore 400 = IF NOT EXIST
    es.indices.create(index=index_name, ignore=400)

    print("")
    print("## Write csv file ({0}) content into Elasticsearch".format(csv_filename))

    print("")
    print("## Update every 1000 rows proccesed ##")

    rows_counter = 0
    with open(csv_filename, "r") as f:
        reader = csv.reader(f, skipinitialspace=True, quoting=csv.QUOTE_ALL, escapechar='\\')
        headers, headers_index_mapping = get_headers(reader)
        doc_type = "by_{0}".format("-".join(keys))

        for row in reader:
            es_id = get_es_id(row, headers, headers_index_mapping, keys)
            doc_data = get_row_data(row, headers)

            res = es.index(index=index_name, doc_type=doc_type, id=es_id, body=doc_data)
            rows_counter += 1

            # Print update every 1000 rows
            if rows_counter % 1000 == 0:
                print("Rows processed: {0} ".format(rows_counter))


    # After all the inserts, make a refresh, just in case
    print("")
    print("## After all inserts, refresh index (just in case)")
    es.indices.refresh(index=index_name)


    # Total processed rows
    print("")
    print("")
    print("### Total Rows Processed: {0} ###".format(rows_counter))
    print("")
    print("")


if __name__ == "__main__":
    keys = get_primary_key_fields(opts.cql_schema_file_name, opts.csv_file_name, opts.ignore_cql_schema)
    insert_data(opts.csv_file_name, keys)
