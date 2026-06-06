#!/bin/bash

echo "Waiting for ScyllaDB to be ready..."
until docker exec -i scylla-node1 cqlsh -e "describe cluster" >/dev/null 2>&1; do
  sleep 2
  echo "Still waiting..."
done
echo "ScyllaDB is ready!"

# Create keyspace if it doesn't exist
docker exec -i scylla-node1 cqlsh <<EOF
CREATE KEYSPACE IF NOT EXISTS catalog WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy', 'DC1' : 3 };
EOF

echo "Keyspace created"
sleep 3

# Use keyspace and create table if it doesn't exist
docker exec -i scylla-node1 cqlsh <<EOF
USE catalog;

CREATE TABLE IF NOT EXISTS mutant_data (
   first_name text,
   last_name text,
   address text,
   website text,
   picture_file map<text, blob>,
   PRIMARY KEY((first_name, last_name))
);
EOF

echo "Table created"

