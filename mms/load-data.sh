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
   picture_location text,
   PRIMARY KEY((first_name, last_name))
);
EOF

echo "Table created"


# For the data inserts, we can make them idempotent by first checking if the record exists
docker exec -i scylla-node1 cqlsh <<EOF
USE catalog;
INSERT INTO mutant_data (first_name, last_name, address, picture_location)
VALUES ('Bob', 'Loblaw', '1313 Mockingbird Lane', 'http://www.facebook.com/bobloblaw')
IF NOT EXISTS;
EOF


docker exec -i scylla-node1 cqlsh <<EOF
USE catalog;
INSERT INTO mutant_data (first_name, last_name, address, picture_location)
VALUES ('Bob', 'Zemuda', '1202 Coffman Lane', 'http://www.facebook.com/bzemuda')
IF NOT EXISTS;
EOF

docker exec -i scylla-node1 cqlsh <<EOF
USE catalog;
INSERT INTO mutant_data (first_name, last_name, address, picture_location)
VALUES ('Jim', 'Jeffries', '1211 Hollywood Lane', 'http://www.facebook.com/jeffries')
IF NOT EXISTS;
EOF


echo "Data inserted"

# select all data
docker exec -i scylla-node1 cqlsh <<EOF
USE catalog;
SELECT * FROM mutant_data;
EOF




