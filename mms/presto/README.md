## Presto in Docker for the Mutant Monitoring Blog Series

### Prerequisites ###

1. [Docker](https://docs.docker.com/engine/installation/).

2. This [repository](https://github.com/scylladb/scylla-code-samples) cloned on your machine.

### Building and Running the Scylla Cluster
```
cd scylla-code-samples/mms
docker-compose up -d
```

### Create a keyspace and Add the Mutant Data

```
docker exec -it mms_scylla-node1_1 cqlsh

CREATE KEYSPACE catalog WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy','DC1' : 3};

use catalog;

CREATE TABLE mutant_data (
first_name text,
last_name text, 
address text, 
picture_location text,
PRIMARY KEY((first_name, last_name)));

insert into mutant_data ("first_name","last_name","address","picture_location") VALUES ('Bob','Loblaw','1313 Mockingbird Lane', 'http://www.facebook.com/bobloblaw') ;

insert into mutant_data ("first_name","last_name","address","picture_location") VALUES ('Bob','Zemuda','1202 Coffman Lane', 'http://www.facebook.com/bzemuda') ;

insert into mutant_data ("first_name","last_name","address","picture_location") VALUES ('Jim','Jeffries','1211 Hollywood Lane', 'http://www.facebook.com/jeffries') ;
```


### Building and Running the Presto Container

```
cd scylla-code-samples/mms/presto
docker build -t presto .
docker run --name presto --network mms_web -p 8080:8080 -d presto
```

### Running Queries against Scylla from the Presto Container
```
docker exec -it presto bash
./presto-cli.jar --catalog cassandra

use catalog;
select * from catalog.mutant_data where first_name like 'Bob';

first_name | last_name |      address      |        picture_location
------------+-----------+-------------------+---------------------------------
Bob        | Zemuda    | 1202 Coffman Lane | http://www.facebook.com/bzemuda
Bob        | Loblaw    | 1313 Mockingbird Lane | http://www.facebook.com/bobloblaw
(2 rows)

```

### Accessing the Presto Web Interface

Navigate to [http://127.0.0.1:8080](http://127.0.0.1:8080) in your web browser.