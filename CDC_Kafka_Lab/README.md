# Scylla CDC Connector with Kafka  
Instructions for setting up a three node Scylla cluster in Docker, with CDC enabled, and connecting it to Kafka using the [ScyllaDB CDC Source connector](https://github.com/scylladb/scylla-cdc-source-connector). 
More info in the Scylla University lesson [Change Data Capture](https://university.scylladb.com/courses/scylla-operations/lessons/change-data-capture-cdc/). 

### ### Instructions for setting up a Scylla Cluster from this repo.
```
cd CDC_Kafka_Lab
docker-compose -f docker-compose-scylladb.yml up -d
```

Run bash in the node:
```
docker exec -it scylla-node1 bash
```

Followed by scylla commands, like
```
nodetool status
```
or
```
cqlsh
```

### To create a keyspace and table with CDC enabled
```
docker exec -it scylla-node1 cqlsh
```

```
CREATE KEYSPACE ks WITH replication = {'class': 'NetworkTopologyStrategy', 'replication_factor' : 1};
```

```
CREATE TABLE ks.my_table (pk int, ck int, v int, PRIMARY KEY (pk, ck, v)) WITH cdc = {'enabled':true};
```


### Confluent Setup and Connector Configuration
Download the Confluent platform docker-compose.yml file to set up the services:

```
wget -O docker-compose-confluent.yml https://raw.githubusercontent.com/confluentinc/cp-all-in-one/7.3.0-post/cp-all-in-one/docker-compose.yml
```

Download the ScyllaDB CDC connector:

```
wget -O scylla-cdc-plugin.jar https://github.com/scylladb/scylla-cdc-source-connector/releases/download/scylla-cdc-source-connector-1.0.1/scylla-cdc-source-connector-1.0.1-jar-with-dependencies.jar
```

Add the cdc plugin file as a volume to the docker-compose-confluent.yml file ad launch Confluent:

```
docker-compose -f docker-compose-confluent.yml up -d 
```

Wait for a minute or so, then access http://localhost:9021  for the Confluent web GUI. From the GUI, add the ScyllaConnector using the Confluent dashboard.


### Destroying the Clusters 
```
cd CDC_Kafka_Lab
docker-compose -f docker-compose-scylladb.yml kill
docker-compose -f docker-compose-scylladb.yml rm -f
docker-compose -f docker-compose-confluent.yml kill
docker-compose -f docker-compose-confluent.yml rm -f
```



