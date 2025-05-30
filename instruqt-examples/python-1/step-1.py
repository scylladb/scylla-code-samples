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

    def stop(self):
        self.cluster.shutdown()

if __name__ == "__main__":
    app = App()
    if app.session:
        print("Successfully connected to ScyllaDB database!")
    else:
        print("Failed to connect to ScyllaDB database.")
    app.stop()

