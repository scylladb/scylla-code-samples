#!/usr/bin/python-pip
import sys
import uuid
import time

from cassandra.cluster import Cluster
#from cassandra.auth import PlainTextAuthProvider
from cassandra.policies import DCAwareRoundRobinPolicy
from cassandra.query import SimpleStatement
from cassandra import ConsistencyLevel

# Parsing args
hostname = sys.argv[1]
#username = sys.argv[2]
#password = sys.argv[3]
desired_response_counter = int(sys.argv[2])

# Logging in
#auth_provider = PlainTextAuthProvider(username=username, password=password)
cluster = Cluster([hostname],
#    auth_provider=auth_provider,
    load_balancing_policy=DCAwareRoundRobinPolicy(local_dc='us-east'))
session = cluster.connect('replicated')
# Predefining queries
truncate_test = SimpleStatement("TRUNCATE replicated.test",
    consistency_level=ConsistencyLevel.ALL)
truncate_test_count = SimpleStatement("TRUNCATE replicated.test_count",
        consistency_level=ConsistencyLevel.ALL)
insert_into_test = SimpleStatement("""
    INSERT INTO replicated.test (id, insertion_date, desired_response_counter, some_data)
    VALUES (%s, now(), %s, 'dummy');
""", consistency_level=ConsistencyLevel.LOCAL_ONE)

while True:
        # Inserting new test value
        next_uuid = uuid.uuid1()
        response_counter = 0
        session.execute(insert_into_test, (next_uuid, desired_response_counter))
        # Waiting for all responses to arrive
        while response_counter < desired_response_counter:
            rs = session.execute ("""
                SELECT * FROM replicated.test_count WHERE id={}
            """.format(next_uuid))
            result = rs.current_rows
#            print result
            if len(result) > 0:
                response_counter = result[0].response_counter
        # Clearing results, preparing for next round
#        print 'Initiating next round'
        session.execute(truncate_test)
        session.execute(truncate_test_count)

# insert rate, when using sleep=1, write is 1/sec. without it write is ~5/sec
#        time.sleep(1)
