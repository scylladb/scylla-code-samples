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

    def delete_mutant(self, first_name, last_name):
        print(f"\nDeleting {first_name} {last_name}...")
        self.session.execute(f"DELETE FROM mutant_data WHERE last_name = '{last_name}' and first_name = '{first_name}'")
        print("Deleted.\n")

    def check_for_mutant(self, first_name, last_name):
        result = self.session.execute(query=f"SELECT * FROM mutant_data WHERE first_name = '{first_name}' and last_name = '{last_name}'")
        if result.one():
            return True
        else:
            return False

    def stop(self):
        self.cluster.shutdown()

    def add_mutant(self, first_name, last_name, address, picture_location):
        raise NotImplementedError("You need to implement the 'add_mutant' function") # TODO: Delete this line and implement the function

if __name__ == "__main__":
    app = App()
    app.add_mutant(first_name="Miles", last_name="Morales", address="42 Brooklyn St", picture_location="https://www.facebook.com/miles-morales")
    app.show_mutant_data()
    if app.check_for_mutant(first_name="Miles", last_name="Morales"):
        print("Congratulations! You've successully added Miles in the mutant database and have passed the challenge!")
    app.stop()

