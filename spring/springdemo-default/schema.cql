create keyspace springdemo with replication={'class':'NetworkTopologyStrategy', 'replication_factor':1};

use springdemo;

CREATE TABLE monster(
   id timeuuid PRIMARY KEY,
   name text,
   description text,
   isalive boolean
);
