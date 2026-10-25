# Scylla CDC Connector with Kafka  
Instructions for setting up a three node Scylla cluster in Docker, with CDC enabled, and connecting it to Kafka using the [ScyllaDB CDC Source connector](https://github.com/scylladb/scylla-cdc-source-connector). 
More info in the Scylla University lesson [Change Data Capture](https://university.scylladb.com/courses/scylla-operations/lessons/change-data-capture-cdc/). 

### Instructions for setting up a Scylla Cluster from this repo.
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
CREATE KEYSPACE ks WITH replication = {'class': 'NetworkTopologyStrategy', 'replication_factor' : 1} AND TABLETS = {'enabled': false};
```

```
CREATE TABLE ks.my_table (pk int, ck int, v int, PRIMARY KEY (pk, ck, v)) WITH cdc = {'enabled':true};
```

Insert a row to test CDC capture:
```
INSERT INTO ks.my_table(pk, ck, v) VALUES (1, 1, 20);
```


### Confluent Setup and Connector Configuration

Download the ScyllaDB CDC connector (v2.0.4):

```
wget -O scylla-cdc-plugin.jar https://github.com/scylladb/scylla-cdc-source-connector/releases/download/scylla-cdc-source-connector-2.0.4/scylla-cdc-source-connector-2.0.4-jar-with-dependencies.jar
```

The `docker-compose-confluent.yml` file is already included in this directory with the connector jar mounted into the Kafka Connect plugin path. Launch Confluent:

```
docker-compose -f docker-compose-confluent.yml up -d
```

Wait for Kafka Connect to be ready (returns `[]`):
```
curl -s http://localhost:8083/connectors
```

Get the scylla-node1 IP address:
```
docker inspect scylla-node1 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}'
```

Register the ScyllaDB CDC connector via the Kafka Connect REST API (replace `<SCYLLA_IP>` with the IP from above):

```
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d '{
    "name": "ScyllaConnector",
    "config": {
      "connector.class": "com.scylladb.cdc.debezium.connector.ScyllaConnector",
      "scylla.cluster.ip.addresses": "<SCYLLA_IP>:9042",
      "scylla.table.names": "ks.my_table",
      "topic.prefix": "MyScyllaCluster",
      "tasks.max": "1",
      "key.converter": "org.apache.kafka.connect.json.JsonConverter",
      "key.converter.schemas.enable": "false",
      "value.converter": "org.apache.kafka.connect.json.JsonConverter",
      "value.converter.schemas.enable": "false"
    }
  }'
```

Check connector status:
```
curl -s http://localhost:8083/connectors/ScyllaConnector/status | python3 -m json.tool
```

The connector task should show `"state": "RUNNING"`. A topic named `MyScyllaCluster.ks.my_table` will be created automatically.

Now that the connector is running, insert another row, so there's a change it captures live:
```
docker exec -it scylla-node1 cqlsh -e "INSERT INTO ks.my_table(pk, ck, v) VALUES (2, 2, 30);"
```

Verify CDC events are captured by reading from the topic. You should see the row with `pk` 2, and usually also the row with `pk` 1 that you inserted before starting the connector:
```
docker exec broker kafka-console-consumer \
  --bootstrap-server broker:29092 \
  --topic MyScyllaCluster.ks.my_table \
  --from-beginning \
  --max-messages 10 \
  --timeout-ms 15000
```


### Destroying the Clusters 
```
cd CDC_Kafka_Lab
docker-compose -f docker-compose-scylladb.yml kill
docker-compose -f docker-compose-scylladb.yml rm -f
docker-compose -f docker-compose-confluent.yml kill
docker-compose -f docker-compose-confluent.yml rm -f
```


