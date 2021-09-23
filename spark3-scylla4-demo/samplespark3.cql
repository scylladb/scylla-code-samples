CREATE KEYSPACE myOwnKeyspace WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1};

use myOwnKeyspace;

CREATE TABLE sparseTable ( uid int, name text, lname text, lettersinname int, PRIMARY KEY((uid)));


insert into sparseTable(uid, name, lname) values (1, 'rick', 'sanchez');
insert into sparseTable(uid, name, lname) values (4, 'rust', 'cohle');

insert into sparseTable(uid, name, lname) values (7, 'joe', 'joo');
insert into sparseTable(uid, name, lname) values (102, 'byran', 'bar');

insert into sparseTable(uid, name, lname, lettersinname) values (502, 'foo', 'bar',6);
