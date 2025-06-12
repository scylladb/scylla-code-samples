-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS catalog 
WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy', 'replication_factor' : 3 };

-- Use keyspace
USE catalog;

-- Create table for mutant data
CREATE TABLE IF NOT EXISTS mutant_data (
   first_name text,
   last_name text,
   address text,
   website text,
   picture_file map<text, blob>,
   PRIMARY KEY((first_name, last_name))
); 