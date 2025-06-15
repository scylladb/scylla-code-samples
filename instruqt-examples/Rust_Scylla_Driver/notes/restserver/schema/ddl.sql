CREATE KEYSPACE IF NOT EXISTS mykb WITH replication = {'class': 'NetworkTopologyStrategy', 'replication_factor' : 1};
CREATE TABLE IF NOT EXISTS mykb.notes (
   id uuid,
   topic text,
   content text,
   PRIMARY KEY (id)
) WITH comment = 'Notes Table' AND caching = {'enabled': 'true'} AND compression = {'sstable_compression': 'LZ4Compressor'};
-- add eventually a timestamp column? or use writetimestamp to sort?

-- interesting idea - remodel above to support "Notebooks" which contain notes
-- in Scylla don't forget that single shard owns rows based on PK, so you need to make sure PK
-- has ideally minimum number of rows to be able to scale to millions of Notebooks
-- limit of partition in Scylla is 100k rows (or 1G in size), then it cannot guarantee low latencies

-- bucketing for notebooks?
-- add eventually a timestamp column?
-- can below be done with MV? :-) ?
CREATE TABLE IF NOT EXISTS mykb.notebooks (
   id uuid,
   bucket int,
   createdat timestamp,
   noteid uuid,
   PRIMARY KEY ((id, bucket), createdat)
)  WITH CLUSTERING ORDER BY (createdat DESC) AND comment = 'Notebooks Table' AND caching = {'enabled': 'true'} AND compression = {'sstable_compression': 'LZ4Compressor'};
