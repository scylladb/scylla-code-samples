#!/bin/bash

echo "Connecting to ScyllaDB and setting up the catalog keyspace..."

docker exec -i node1 cqlsh <<EOF
CREATE KEYSPACE IF NOT EXISTS catalog
WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy', 'replication_factor' : 3 };

USE catalog;

CREATE TABLE IF NOT EXISTS mutant_data (
   first_name text,
   last_name text,
   address text,
   picture_location text,
   PRIMARY KEY((first_name, last_name))
);

INSERT INTO mutant_data (first_name, last_name, address, picture_location)
VALUES ('Bob', 'Loblaw', '1313 Mockingbird Lane', 'http://www.facebook.com/bobloblaw');

INSERT INTO mutant_data (first_name, last_name, address, picture_location)
VALUES ('Bob', 'Zemuda', '1202 Coffman Lane', 'http://www.facebook.com/bzemuda');

INSERT INTO mutant_data (first_name, last_name, address, picture_location)
VALUES ('Jim', 'Jeffries', '1211 Hollywood Lane', 'http://www.facebook.com/jeffries');

SELECT * FROM mutant_data;
EOF