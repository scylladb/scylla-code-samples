## Scylla in Docker for the Mutant Monitoring Blog Series

### Instructions on setting up a Scylla Cluster from this repo

```
cd mms
docker-compose up -d
docker exec -it mms_scylla-node1_1 sh
```
### Destroying the Scylla Cluster 
```
cd mms
docker-compose kill
docker-compose rm -f
```

### Using Presto to Run Queries from the Scylla Cluster
See our guide [here](https://github.com/scylladb/scylla-code-samples/tree/master/mms/presto)