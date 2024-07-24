#! /usr/bin/env python

import argparse
import random
import time

from cassandra import ConsistencyLevel
from cassandra.cluster import Cluster
from cassandra.cqltypes import LongType

parser = argparse.ArgumentParser(add_help=True)
parser.add_argument('-c1', action="store", dest="C1", default="localhost")

opts = parser.parse_args()

node_ips = opts.C1.split(',')
print("Listing Cluster Ip's: " + str(node_ips))

# Creating the DB Schema

drop_ks = "DROP KEYSPACE IF EXISTS direct_ts"
create_ks = """
CREATE KEYSPACE direct_ts WITH replication = {
    'class': 'NetworkTopologyStrategy', 
    'replication_factor': '3'
}  AND durable_writes = true
"""

create_t1 = """
    CREATE TABLE direct_ts.data_points (
        rack_id text,
        sensor_id text,
        curr_epoch timestamp,
        value int,
        PRIMARY KEY ((rack_id, sensor_id), curr_epoch)
    ) WITH CLUSTERING ORDER BY (curr_epoch DESC)
"""

# connect to cluster and execute and migra the schema
print("Connecting to Cluster...")
db1 = Cluster(node_ips).connect()

print("Re/creating Keyspace and Table...")
db1.execute(drop_ks)
db1.execute(create_ks)
db1.execute(create_t1)

# preparing the statement used to insert data
insert_statement = "insert into direct_ts.data_points (rack_id,sensor_id,curr_epoch,value) values (?,?,?,?) using TIMESTAMP ?"

insert_statement_prepared = db1.prepare(insert_statement)
insert_statement_prepared.consistency_level = ConsistencyLevel.ONE

start_time = time.time()

start_range1 = 1
start_range2 = 1
num_racks = 100
num_sensors = 100
num_repeat = 2001
total_inserts = 0

print("Inserting " + str(num_racks * num_sensors * num_repeat) + " rows")
for repeats in range(1, num_repeat):

    curr_epoch = int(round(time.time() * 1000))

    for rack_id in range(start_range1, start_range1 + num_racks):
        for sensor_id in range(start_range2, start_range2 + num_sensors):
            # Prepared Statement Payload
            values = [
                "rack__" + str(rack_id),
                "sensor__" + str(sensor_id),
                curr_epoch,
                random.randint(1, 500),
                LongType.__init__(time.time() * 1000)
                # Timestamp needs to be treated as LongType on this "USING TIMESTAMP" clause
            ]
            db1.execute_async(insert_statement_prepared, values)
            total_inserts += 1

            if total_inserts % 10000 == 0:
                print("Inserted " + str(total_inserts) + " rows")

print("Started at: " + start_time.__str__())
print("--- %s seconds ---" % (time.time() - start_time))
