## Scylla Monitoring System in Docker for the Mutant Monitoring Blog Series

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


### Building and Running the Scylla Monitoring Container

```
cd scylla-code-samples/mms/monitoring
docker build -t monitoring .
docker run --name monitoring --network mms_web -p 3000:3000 -d monitoring
```
There is a 60 second delay after the container is run before you can view the web interface.

### Accessing the Scylla Monitoring Web Interface

Navigate to [http://127.0.0.1:3000](http://127.0.0.1:3000) in your web browser.

Login with ```admin``` as the username and password.


