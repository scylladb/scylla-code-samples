CREATE KEYSPACE datastore WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy', 'replication_factor' : 1} ;

use datastore;

drop INDEX owner_id_index;
DROP table data;

CREATE TABLE data (  id uuid,
                       group_id uuid,
                       owner_id uuid,
                       data blob,
                       changed_at timestamp,
                       PRIMARY KEY ((id, group_id)) ) WITH compaction = {'class': 'IncrementalCompactionStrategy', 'space_amplification_goal': '1.75'}
                                                       AND compression = {'compression_level': '3', 'sstable_compression': 'org.apache.cassandra.io.compress.ZstdCompressor'};

CREATE INDEX owner_id_index ON datastore.data(owner_id);

insert into data(id, group_id, owner_id, data, changed_at) values (e7ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data1'), '2017-04-01');
insert into data(id, group_id, owner_id, data, changed_at) values (f7ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data2'), '2017-04-02');
insert into data(id, group_id, owner_id, data, changed_at) values (a7ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data3'), '2017-04-03');
insert into data(id, group_id, owner_id, data, changed_at) values (b7ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data4'), '2017-04-04');

alter table datastore.data WITH default_time_to_live = 300000;

insert into data(id, group_id, owner_id, data, changed_at) values (17ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data5'), '2017-04-05');
insert into data(id, group_id, owner_id, data, changed_at) values (27ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data6'), '2017-04-06');
insert into data(id, group_id, owner_id, data, changed_at) values (37ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data7'), '2017-04-07');
insert into data(id, group_id, owner_id, data, changed_at) values (47ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, TextAsBlob('data8'), '2017-04-08');

select  * from datastore.data;

'lookup
CREATE TABLE data_lookup (  id uuid,
                       group_id uuid,
                       owner_id uuid,
                       bucket smallint,
                       changed_at timestamp,
                       PRIMARY KEY ((owner_id, group_id, bucket)) ) WITH compaction = {'class': 'IncrementalCompactionStrategy', 'space_amplification_goal': '1.75'}
                                                       AND compression = {'compression_level': '3', 'sstable_compression': 'org.apache.cassandra.io.compress.ZstdCompressor'};
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (e7ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, 0, '2017-04-01');
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (f7ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, 1, '2017-04-02');
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (a7ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, 2, '2017-04-03');
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (b7ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, 3, '2017-04-04');

alter table datastore.data WITH default_time_to_live = 300000;

insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (17ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, 4, '2017-04-05');
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (27ae5cf3-d358-4d99-b900-85902fda9bb0, 27dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, 5, '2017-04-06');
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (37ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, d46cb523-4202-4212-a8e9-024d46529907, 6, '2017-04-07');
insert into data_lookup(id, group_id, owner_id, bucket, changed_at) values (47ae5cf3-d358-4d99-b900-85902fda9bb0, 37dc4604-3d36-4b69-b053-954db147fd03, c46cb523-4202-4212-a8e9-024d46529907, 7, '2017-04-08');

select  * from datastore.data_lookup;

select id,group_id,owner_id,ttl(data),changed_at from datastore.data;
