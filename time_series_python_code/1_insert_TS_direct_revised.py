#! /usr/bin/env python
# -*- coding: latin-1 -*-
#

import os
import time
import random
# import logging
import argparse
import concurrent.futures
import cassandra.cluster
from cassandra import ConsistencyLevel
from cassandra.concurrent import execute_concurrent_with_args
from cassandra.query import BatchStatement

parser = argparse.ArgumentParser(add_help=True)

parser.add_argument('-c1', action="store", dest="C1", default="127.0.0.1")

opts = parser.parse_args()

IP_C1 = opts.C1.split(',')

# Creating the DB Schema - need to run the CREATE MATERIALIZED VIEW manually using cqlsh, since it does not work from the script
create_ks = "create keyspace if not exists direct_ts with replication = {'class' : 'SimpleStrategy', 'replication_factor' : 3};"
create_t1 = "create table if not exists direct_ts.data_points (rack_id text, sensor_id text, curr_epoch timestamp, value int, primary key ((rack_id,sensor_id),curr_epoch)) WITH CLUSTERING ORDER BY (curr_epoch DESC);"
# create_2i = "CREATE INDEX data_points_curr_epoch_idx ON direct_ts.data_points (curr_epoch); CREATE INDEX data_points_value_idx ON direct_ts.data_points (value);"


# connect to cluster
db1 = cassandra.cluster.Cluster(IP_C1).connect()

db1.execute(create_ks)
db1.execute(create_t1)
# time.sleep(2)
# db1.execute(create_2i)

insert_statement = "insert into direct_ts.data_points (rack_id,sensor_id,curr_epoch,value) values (?,?,?,?) using TIMESTAMP ?"

#insert_statement_prepared = []
#insert_statement_prepared.append(db1.prepare(insert_statement[0]))
CL1 = ConsistencyLevel.ONE if random.random() < 0.2 else ConsistencyLevel.ONE
insert_statement_prepared = db1.prepare(insert_statement)
insert_statement_prepared.consistency_level = CL1


# def execute(values):
#     # randomly set consistency level to quorum
#     # which will fail on a single node cluster
#     CL1 = ConsistencyLevel.ONE if random.random() < 0.2 else ConsistencyLevel.ONE
#     insert_statement_prepared[0].consistency_level = CL1
#
#     # put writes into a list
#     writes = []
#     # insert 1st statement into db1 session, table 1
#     writes.append(db1.execute_async(insert_statement_prepared[0], values))
#
#     # loop over futures and output success/fail
#     results = []
#     for i in range(0, len(writes)):
#         try:
#             row = writes[i].result()
#             results.append(1)
#         except Exception:
#             results.append(0)
#
#     results.append(values)
#     #    log(results)
#
#     # did we have failures?
#     if (results[0] == 0):
#         # do something, like re-write to cluster 1
#         log('Write to cluster 1 failed')


start_time = time.time()

start_range1 = 1
start_range2 = 1
num_racks = 100
num_sensors = 100
num_repeat = 2001
for x in range(1, num_repeat):
    #    str=""
    #    #time.sleep(1)
    curr_epoch = int(round(time.time() * 1000))
    #       print "======================"
    #       print x
    #       print "Current time " + time.strftime("%X")
    #       print "======================"
    for y in range(start_range1, start_range1 + num_racks):
        for z in range(start_range2, start_range2 + num_sensors):
            values = ["rack__" + str(y), "sensor__" + str(z), curr_epoch, random.randint(1, 500),
                      time.time() * 1000000]
            # execute(values)
            db1.execute_async(insert_statement_prepared, values)

#execute_concurrent_with_args(db1, insert_statement_prepared, values, concurrency=1)
#db1.execute_async(insert_statement_prepared, values)

print("--- %s seconds ---" % (time.time() - start_time))
