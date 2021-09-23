CREATE KEYSPACE mykeyspace WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1};

use mykeyspace;

CREATE TABLE users ( user_id int, fname text, lname text, PRIMARY KEY((user_id)));


insert into users(user_id, fname, lname) values (1, 'rick', 'sanchez');
insert into users(user_id, fname, lname) values (4, 'rust', 'cohle');

insert into users(user_id, fname, lname) values (7, 'joe', 'joo');
insert into users(user_id, fname, lname) values (102, 'byran', 'bar');

insert into users(user_id, fname, lname) values (105, 'Adela', 'Killer');

