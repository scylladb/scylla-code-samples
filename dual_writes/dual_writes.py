#! /usr/bin/env python
# -*- coding: latin-1 -*-
# 
import os
import logging
import time
import uuid
import argparse
import random
import concurrent.futures 
import cassandra.cluster
from cassandra import ConsistencyLevel
from cassandra.query import BatchStatement

parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-c1', action="store", dest="C1", default="127.0.0.1")
parser.add_argument('-c2', action="store", dest="C2", default="127.0.0.1")
parser.add_argument('-w', action="store", dest="RANDOM_WRITES", default="10")

opts = parser.parse_args()

IP_C1 = opts.C1.split(',')
IP_C2 = opts.C2.split(',')
RANDOM_WRITES = int(opts.RANDOM_WRITES)
LOG_FILE = "./dual_writes.log"

def log(message):
    print(message)
    logging.info(message)

logging.basicConfig(filename=LOG_FILE,level=logging.DEBUG,format="%(asctime)s %(message)s",datefmt="%b %d %Y %H:%M:%S")

create_ks = "create keyspace if not exists dual_writes with replication = {'class' : 'SimpleStrategy', 'replication_factor' : 3};"
create_t1 = "create table if not exists dual_writes.t1 (c1 int, c2 varchar, primary key (c1) );"
create_t2 = "create table if not exists dual_writes.t2 (c1 int, c2 varchar, primary key (c1) );"

#connect to cluster 1
db1 = cassandra.cluster.Cluster(IP_C1).connect()
#connect to cluster 2
db2 = cassandra.cluster.Cluster(IP_C2).connect()

db1.execute(create_ks)
db1.execute(create_t1)

db2.execute(create_ks)
db2.execute(create_t2)

insert_statement = []
insert_statement.append("insert into dual_writes.t1 (c1,c2) values (?,?) using TIMESTAMP ?")
insert_statement.append("insert into dual_writes.t2 (c1,c2) values (?,?) using TIMESTAMP ?")

insert_statement_prepared = []
insert_statement_prepared.append(db1.prepare(insert_statement[0]))
insert_statement_prepared.append(db2.prepare(insert_statement[1]))

def execute(values):
    
    #randomly set consistency level to quorum 
    #which will fail on a single node cluster
    CL1 = ConsistencyLevel.QUORUM if random.random() < 0.2 else ConsistencyLevel.ONE
    CL2 = ConsistencyLevel.QUORUM if random.random() < 0.2 else ConsistencyLevel.ONE
    insert_statement_prepared[0].consistency_level = CL1
    insert_statement_prepared[1].consistency_level = CL2
    
    # put both writes (cluster 1 and cluster 2) into a list
    writes = []
    #insert 1st statement into db1 session, table 1
    writes.append(db1.execute_async(insert_statement_prepared[0], values))
    #insert 2nd statement into db2 session, table 2
    writes.append(db2.execute_async(insert_statement_prepared[1], values))
    
    # loop over futures and output success/fail
    results = []
    for i in range(0,len(writes)):
        try:
            row = writes[i].result()
            results.append(1)
        except Exception:
            results.append(0)
            #log exception if you like
            #logging.exception('Failed write: %s', ('Cluster 1' if (i==0) else 'Cluster 2'))
        
    results.append(values)
    log(results)
    
    #did we have failures?
    if (results[0]==0):
        #do something, like re-write to cluster 1
        log('Write to cluster 1 failed')
    if (results[1]==0):
        #do something, like re-write to cluster 2
        log('Write to cluster 2 failed')

for x in range(0,RANDOM_WRITES):    
    #explicitly set a writetime in microseconds
    values = [ random.randrange(0,1000) , str(uuid.uuid4()) , int(time.time()*1000000) ]
    
    execute( values )
    
