CREATE KEYSPACE thespace WITH replication = {'class': 'SimpleStrategy', 'replication_factor' : 2};

CREATE TABLE planets (
    name text PRIMARY KEY,
    size int
);