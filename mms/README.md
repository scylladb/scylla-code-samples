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
### Importing the MMS keyspaces and data automatically 

Add the following argument under ```environment``` for ```scylla-node1:``` in docker-compose.yml:

```
  - IMPORT=IMPORT
```

Then re-run docker-compose:
```
docker-compose kill
docker-compose rm -f
docker-compose up -d
```
The data will be imported about 60 seconds after the containers come up.

### Using Scylla Monitoring to monitor the Scylla Cluster
See our guide [here](https://github.com/scylladb/scylla-code-samples/tree/master/mms/monitoring)


### Using Presto to Run Queries from the Scylla Cluster
See our guide [here](https://github.com/scylladb/scylla-code-samples/tree/master/mms/presto)

### Using Zeppelin to Run Queries from the Scylla Cluster
See our guide [here](https://github.com/scylladb/scylla-code-samples/tree/master/mms/zeppelin)