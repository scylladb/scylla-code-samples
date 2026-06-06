# Integrate ScyllaDB and Feast
[Feast](https://feast.dev/) is a popular open-source feature store for production ML. You can use several online stores when using Feast, including ScyllaDB. ScyllaDB, a low-latency and high-throughput database, serves perfectly as an online store. In this section, you'll see how you can integrate your ScyllaDB Cloud database with Feast as an online store.

If you want to learn more about Feast, read the [Feast documentation](https://docs.feast.dev/).

## Feast + ScyllaDB online store configuration example
ScyllaDB is Cassandra-compatible which means you can use the built-in Cassandra connector of Feast.

To set up ScyllaDB as a Feast online store you need to 

1. Install the Feast + Cassandra connector
1. Edit the Feast configuration file

### Install the Feast + Cassandra connector
```
pip install feast[cassandra]
```

### Edit the Feast configuration file 
```yaml
# feature_store.yaml
project: repo
registry: data/registry.db
provider: local
online_store:
    type: cassandra
    hosts:
        - node-0.aws-us-east-1.xxxxxxx.clusters.scylla.cloud
        - node-1.aws-us-east-1.xxxxxxx.clusters.scylla.cloud
        - node-2.aws-us-east-1.xxxxxxx.clusters.scylla.cloud
    username: scylla
    password: xxxxxxx
    keyspace: feast
entity_key_serialization_version: 2

```

For more information, read the [Feast documentation](https://docs.feast.dev/v/master/reference/online-stores/scylladb).
