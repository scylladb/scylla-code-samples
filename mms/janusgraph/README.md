## Scylla in Docker for the [Mutant Monitoring University Course](https://university.scylladb.com/courses/the-mutant-monitoring-system-training-course/lessons/a-graph-data-system-powered-by-scylladb-and-janusgraph/) - JanusGraph Lessons 

### Instructions for starting the JanusGraph server and a three-node Scylla Cluster that is used as the data storage layer for JanusGraph. 

```
cd mms/janusgraph/
docker-compose  -f ./docker-compose-cql.yml up -d

```

### Destroying the Scylla Cluster 
```
cd mms/janusgraph
docker-compose -f ./docker-compose-cql.yml kill
docker-compose rm -f ./docker-compose-cql.yml
```

