CREATE KEYSPACE thespace WITH replication = {'class': 'NetworkTopologyStrategy', 'replication_factor' : 2};

CREATE TABLE planets (
    name text PRIMARY KEY,
    size int
);
