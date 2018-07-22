## Hooking up ScyllaDB and Spark - Introduction

### Launching Spark

To set up your local Spark environment, run the following command:
```shell
docker-compose up -d spark-master spark-worker
```

You can then launch the Spark shell as described in the blog post:
```shell
docker-compose exec spark-master spark-shell \
    --conf spark.driver.host=spark-master
```

### Launching ScyllaDB

To launch ScyllaDB, run the following command:
```shell
docker-compose up -d scylladb-node1 scylladb-node2 scylladb-node3
```

You can also launch the Spark shell afterwards with ScyllaDB support:
```shell
docker-compose exec spark-master spark-shell \
    --conf spark.driver.host=spark-master \
    --conf spark.cassandra.connection.host=scylladb-node1 \
    --packages datastax:spark-cassandra-connector:2.3.0-s_2.11,commons-configuration:commons-configuration:1.10
```

### Shutting everything down

To stop everything:
```shell
docker-compose down
```
