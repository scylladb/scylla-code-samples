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

    def show_mutant_data(self):
        print("Data that we have in the catalog".center(50, "="))
        result = self.session.execute(query="SELECT * FROM mutant_data")
        for row in result:
            print(row.first_name, row.last_name)
        return result

    def add_mutant(self, first_name, last_name, address, picture_location):
        print(f"\nAdding {first_name} {last_name}...")
        self.session.execute(f"INSERT INTO mutant_data (first_name, last_name, address, picture_location) "
                             f"VALUES ('{first_name}','{last_name}','{address}','{picture_location}')")
        print("Added.\n")

    def stop(self):
        self.cluster.shutdown()
            

if __name__ == "__main__":
    app = App()
    if app.session:
        print("Successfully connected to ScyllaDB database!")
    else:
        print("Failed to connect to ScyllaDB database.")
    result = app.show_mutant_data()
    app.add_mutant(first_name='Peter', last_name='Parker',
                   address='1515 Main St', picture_location='https://tinyurl.com/peterparker123')
    result = app.show_mutant_data()
    app.stop()
