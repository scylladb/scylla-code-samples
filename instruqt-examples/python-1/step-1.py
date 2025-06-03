#!/bin/env python3
from cassandra.cluster import Cluster, ExecutionProfile, EXEC_PROFILE_DEFAULT
from cassandra import ConsistencyLevel


class App:
    def __init__(self):
        # Create an execution profile with QUORUM consistency level
        profile = ExecutionProfile(
            consistency_level=ConsistencyLevel.QUORUM
        )
        
        # Create cluster with the execution profile
        self.cluster = Cluster(
            contact_points=[
                ("localhost", 9042),  # node1
                ("localhost", 9043),  # node2
                ("localhost", 9044)   # node3
            ],
            execution_profiles={
                EXEC_PROFILE_DEFAULT: profile
            }
        )
        self.session = self.cluster.connect(keyspace="catalog")

    def stop(self):
        self.cluster.shutdown()

if __name__ == "__main__":
    app = App()
    if app.session:
        print("Successfully connected to ScyllaDB database!")
    else:
        print("Failed to connect to ScyllaDB database.")
    app.stop()

