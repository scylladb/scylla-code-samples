## Scylla in Docker for the Mutant Monitoring Blog Series

### Instructions for setting up a Scylla Cluster from this repo

```
cd mms2
docker-compose up -d
```

Run bash in the node:
```
docker exec -it mms2_scylla-node1_1 bash
```

Followed by scylla commands, like
```
> nodetool status
```
or
```
> cqlsh
```

### Destroying the Scylla Cluster 
```
cd mms2
docker-compose kill
docker-compose rm -f
```
### Importing the MMS keyspaces and data automatically 

```
docker exec mms2_scylla-node1_1 cqlsh -f /mutant-data.txt
```

The data will be imported after a few seconds.

