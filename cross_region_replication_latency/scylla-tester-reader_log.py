#!/usr/bin/python-pip
import sys
from cassandra.cluster import Cluster
#from cassandra.auth import PlainTextAuthProvider
from cassandra.policies import DCAwareRoundRobinPolicy

from time import time
import uuid
import datetime

# Parsing args
hostname = sys.argv[1]
#username = sys.argv[2]
#password = sys.argv[3]

output_file = sys.argv[2]
time_to_run_in_minutes = int(sys.argv[3])

start_time = datetime.datetime.utcnow()
end_time = start_time + datetime.timedelta(minutes=time_to_run_in_minutes)

# Logging in
#auth_provider = PlainTextAuthProvider(username=username, password=password)
cluster = Cluster([hostname],
#    auth_provider=auth_provider,
    load_balancing_policy=DCAwareRoundRobinPolicy(local_dc='us-west-2'))
session = cluster.connect('replicated')

max_latency = 0.0
sum_latency = 0.0
count = 0

output_file = open(output_file, "w")

while True:
    result = []
    while len(result) <= 0:
        resultset = session.execute("""
        SELECT id, insertion_date, now() AS now, some_data, WRITETIME (some_data) FROM replicated.test;
        """)
        result = resultset.current_rows
    
    if result:
        now = datetime.datetime.fromtimestamp((result[0].now.time - 0x01b21dd213814000L) * 100 / 1e9)
        insert_time = datetime.datetime.fromtimestamp((result[0].insertion_date.time - 0x01b21dd213814000L) * 100 / 1e9)
        diff = (now - insert_time).total_seconds()*1000

        output_file.write("{0},{1},{2}\n".format(now, insert_time, diff))

        count += 1
        sum_latency += diff
        if diff > max_latency:
            max_latency = diff

    # Got results
#    print "Lantency for query: %d" % (int(result[0].now) - int(result[0].insertion_date))
    print "Lantency for query: {}".format(diff)
#    print 'id: {}'.format(result[0].id)
    session.execute("""
    UPDATE replicated.test_count
         SET response_counter = response_counter + 1
         WHERE id = {}
    """.format(result[0].id))
        
    while len(result) > 0:
        resultset = session.execute("""
        SELECT id, insertion_date, now() AS now, some_data, WRITETIME (some_data) FROM replicated.test;
        """)
        result = resultset.current_rows

    current_time = datetime.datetime.utcnow()
    if current_time > end_time:
        # we have finished, calculate stats
        print("Max Latency (ms): {0:0.2f}".format(max_latency))
        print("Avg Latency (ms): {0:0.2f}".format(sum_latency / float(count)))
        break
    else:
        print("Time left for the test: {0}".format(end_time - current_time))
#	print len(result)

output_file.close()
