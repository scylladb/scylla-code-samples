CREATE KEYSPACE mykeyspace WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy', 'replication_factor' : 1};

use mykeyspace;

CREATE TABLE users ( user_id int, fname text, lname text, PRIMARY KEY((user_id)));
