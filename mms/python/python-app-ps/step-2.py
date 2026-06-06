#!/bin/env python3
from cassandra.cluster import Cluster, ExecutionProfile, EXEC_PROFILE_DEFAULT
from cassandra import ConsistencyLevel

class App:
    def __init__(self):
        profile = ExecutionProfile(
            consistency_level=ConsistencyLevel.QUORUM
        )
        self.cluster = Cluster(
            contact_points=["scylla-node1", "scylla-node2", "scylla-node3"],
            execution_profiles={EXEC_PROFILE_DEFAULT: profile}
        )
        self.session = self.cluster.connect(keyspace="catalog")
        
        # Prepare insert statement 
        self.insert_ps = self.session.prepare(
            query="INSERT INTO mutant_data (first_name,last_name,address,picture_location) VALUES (?,?,?,?)"
        )

    def show_mutant_data(self):
        print("Data that we have in the catalog".center(50, "="))
        result = self.session.execute(query="SELECT * FROM mutant_data")
        for row in result:
            print(row.first_name, row.last_name)

    def add_mutant(self, first_name, last_name, address, picture_location):
        print(f"\nAdding {first_name} {last_name}...")
        self.session.execute(query=self.insert_ps, parameters=[first_name, last_name, address, picture_location])
        print("Added.\n")

    def stop(self):
        self.cluster.shutdown()

if __name__ == "__main__":
    app = App()
    app.show_mutant_data()
    app.add_mutant(first_name='Peter', last_name='Parker',
                   address='1515 Main St', picture_location='http://www.facebook.com/Peter-Parker/')
    app.show_mutant_data()
    app.stop()