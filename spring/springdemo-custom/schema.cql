CREATE KEYSPACE IF NOT EXISTS springdemo
    WITH replication = {'class':'NetworkTopologyStrategy', 'replication_factor':1}
    AND durable_writes = false;
CREATE TABLE IF NOT EXISTS springdemo.stocks
   (symbol text, date timestamp, value decimal, PRIMARY KEY (symbol, date))
   WITH CLUSTERING ORDER BY (date DESC);

ALTER TABLE springdemo.stocks WITH compaction = { 'class' : 'TimeWindowCompactionStrategy', 'compaction_window_unit' : 'DAYS',  'compaction_window_size' : 31 };

ALTER TABLE springdemo.stocks WITH default_time_to_live = 94608000;

