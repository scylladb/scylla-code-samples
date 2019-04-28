## Apache Zeppelin in Docker for the Mutant Monitoring Blog Series

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

### Building and Running Apache Zeppelin

```
cd scylla-code-samples/mms/zeppelin
docker build -t zeppelin .
docker run --name zeppelin --network mms_web -p 9080:8080 -d zeppelin
```

### Accessing the Zeppelin Web Interface

Navigate to [http://127.0.0.1:9080](http://127.0.0.1:9080) in your web browser.

### Configuring Zeppelin to access Scylla
(This is used as a reference. The Docker image automatically does this for you)
1. Once in the web interface, click on ```anonymous``` -> ```Interpreter```
2. Find cassandra and then click ```edit```
3. Change the value of ```cassandra.cluster``` to scylla-node1
4. Change the value of ```cassandra.hosts```	to scylla-node1,scylla-node2,scylla-node3
5. Click ```save```
6. Click ```ok``` in the proceeding dialog window to update the interpreter and restart with new settings.

### Running Queries against Scylla from Zeppelin
1. Click on Notebook -> ```Create a new Note```
2. Type scylla under ```Note name```
3. Change the default interpreter to cassandra
4. Click ```Create Note```
5. In the ```text box``` type the following:
```
select * from catalog.mutant_data;
```
6. Click the ```play``` button to see the results.


