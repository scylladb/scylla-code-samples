#!/bin/env python3
from cassandra.cluster import Cluster, ExecutionProfile, EXEC_PROFILE_DEFAULT
from cassandra import ConsistencyLevel

class App:
    def __init__(self):
        # Create an execution profile with QUORUM consistency level
        profile = ExecutionProfile(
            consistency_level=ConsistencyLevel.QUORUM
        )
        # Use the profile when creating the cluster
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

    def show_mutant_data(self):
        print("Data that we have in the catalog".center(50, "="))
        result = self.session.execute(query="SELECT * FROM mutant_data")
        for row in result:
            print(row.first_name, row.last_name)

    def stop(self):
        self.cluster.shutdown()

if __name__ == "__main__":
    app = App()
    app.show_mutant_data()  # Just show existing data
    app.stop()
