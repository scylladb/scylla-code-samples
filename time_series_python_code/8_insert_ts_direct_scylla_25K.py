#! /usr/bin/env python
# -*- coding: latin-1 -*-
#
 
import os
import time
import random
#import logging
import argparse
import concurrent.futures 
import cassandra.cluster
from cassandra import ConsistencyLevel
from cassandra.query import BatchStatement


parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-c1', action="store", dest="C1", default="127.0.0.1")

opts = parser.parse_args()

IP_C1 = opts.C1.split(',')

create_ks = "create keyspace if not exists direct_ts with replication = {'class' : 'SimpleStrategy', 'replication_factor' : 3};"
create_t1 = "create table if not exists direct_ts.data_points (sensor_id text, curr_epoch timestamp, value text, primary key (sensor_id,curr_epoch));"

#connect to cluster
db1 = cassandra.cluster.Cluster(IP_C1).connect()

db1.execute(create_ks)
db1.execute(create_t1)

insert_statement = []
insert_statement.append("insert into direct_ts.data_points (sensor_id,curr_epoch,value) values (?,?,?) using TIMESTAMP ?")

insert_statement_prepared = []
insert_statement_prepared.append(db1.prepare(insert_statement[0]))


def execute(values):
    
    #randomly set consistency level to quorum 
    #which will fail on a single node cluster
    CL1 = ConsistencyLevel.QUORUM if random.random() < 0.2 else ConsistencyLevel.ONE
    insert_statement_prepared[0].consistency_level = CL1
	
	# put writes into a list
    writes = []
	#insert 1st statement into db1 session, table 1
    writes.append(db1.execute_async(insert_statement_prepared[0], values))
	
	# loop over futures and output success/fail
    results = []
    for i in range(0,len(writes)):
        try:
            row = writes[i].result()
            results.append(1)
        except Exception:
            results.append(0)
			

    results.append(values)
#    log(results)
	
    #did we have failures?
    if (results[0]==0):
        #do something, like re-write to cluster 1
        log('Write to cluster 1 failed')
    
start_time = time.time()

start_range = 175001
num_sensors = 25000
num_repeat = 2001

for x in range(1,num_repeat):
#    str=""
    time.sleep(1)
    curr_epoch = int(round(time.time() * 1000))
#       print "======================"
#       print x
#       print "Current time " + time.strftime("%X")
#       print "======================"
    for y in range(start_range,start_range+num_sensors):
        values = [ "SENSOR_"+str(y) , curr_epoch , str(random.randint(1,500)) , time.time()*1000000 ]
    	execute( values )
			
print("--- %s seconds ---" % (time.time() - start_time))
