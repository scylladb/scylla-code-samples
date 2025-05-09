#!/bin/env python3
from cassandra.cluster import Cluster
from cassandra import ConsistencyLevel


class App:
    def __init__(self):
        self.cluster = Cluster(contact_points=[
            ("localhost", 9042),  # node1
            ("localhost", 9043),  # node2
            ("localhost", 9044)   # node3
        ])
        self.session = self.cluster.connect(keyspace="catalog")
        self.session.default_consistency_level = ConsistencyLevel.QUORUM

    def show_mutant_data(self):
        print("Data that we have in the catalog".center(50, "="))
        result = self.session.execute(query="SELECT * FROM mutant_data")
        for row in result:
            print(row.first_name, row.last_name)
        return result

    def stop(self):
        self.cluster.shutdown()

if __name__ == "__main__":
    app = App()
    if app.session:
        print("Successfully connected to ScyllaDB database!")
    else:
        print("Failed to connect to ScyllaDB database.")
    result = app.show_mutant_data()
    print(result)
