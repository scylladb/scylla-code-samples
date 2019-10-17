## Scylla Monitoring System in Docker for the Mutant Monitoring Blog Series

### Prerequisites ###

1. [Docker](https://docs.docker.com/engine/installation/).

2. This [repository](https://github.com/scylladb/scylla-code-samples) cloned on your machine.

### Building and Running the Scylla Cluster
```
cd scylla-code-samples/mms
docker-compose up -d
```

### Building and Running the Scylla Monitoring Container

```
cd scylla-code-samples/mms/scylla-grafana-monitoring
cp ../monitoring/scylla_servers.yml prometheus/
cp ../monitoring/node_exporter_servers.yml prometheus/
cp ../monitoring/start-all.sh .
cp ../monitoring/start-grafana.sh .
mkdir data
./start-all.sh -d data
```

### Accessing the Scylla Monitoring Web Interface

Navigate to [http://127.0.0.1:3000](http://127.0.0.1:3000) in your web browser.

Login with ```admin``` as the username and password.

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





