# Scylla CPP Driver  
Instructions for setting up a three node Scylla cluster in Docker and running an example CPP application that interacts with the cluster and performs simple queries. This example uses the [CPP Driver](https://github.com/scylladb/cpp-driver)
More info in the Scylla University Course [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/). 

### ### Instructions for setting up a Scylla Cluster from this repo.
```
cd mms
docker-compose up -d
```

Run bash in the node:
```
docker exec -it mms_scylla-node1_1 bash
```

Followed by scylla commands, like
```
> nodetool status
```
or
```
> cqlsh
```

### To manually add the tracking keyspace and data
docker exec -it mms_scylla-node1_1 cqlsh
CREATE KEYSPACE ks WITH REPLICATION = { 'class' : 'NetworkTopologyStrategy','DC1' : 3};
use ks;
CREATE TABLE IF NOT EXISTS ks.mutant_data (
   first_name text,
   last_name text,
   address text,
   picture_location text,
   PRIMARY KEY((first_name, last_name)));
INSERT INTO ks.mutant_data ("first_name","last_name","address","picture_location") VALUES ('Bob','Loblaw','1313 Mockingbird Lane', 'http://www.facebook.com/bobloblaw');
INSERT INTO ks.mutant_data ("first_name","last_name","address","picture_location") VALUES ('Bob','Zemuda','1202 Coffman Lane', 'http://www.facebook.com/bzemuda');


### Running the CPP Example
The application uses [CPP Driver](https://github.com/scylladb/cpp-driver) which is an open-source Scylla driver for CPP. Start by installing the driver, you can read more about installation in the [Scylla University lesson CPP Driver – Part 1](https://university.scylladb.com/courses/using-scylla-drivers/lessons/cpp-driver-part-1/)
To connect to a cluster, edit the file connect.cpp and change the IP according to the setup of your cluster. Now compile and run the code:
```bash
g++ connect.cpp -lscylla-cpp-driver -o connect
./connect
```

To run a simple query, edit the file query.cpp and change the IP according to the setup of your cluster. Now compile and run the code:
```bash
g++ query.cpp -lscylla-cpp-driver -o query
./query
```

### Destroying the Scylla Cluster 
```
cd mms
docker-compose kill
docker-compose rm -f
```



