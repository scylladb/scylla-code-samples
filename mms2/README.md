## Scylla in Docker for the Mutant Monitoring Blog Series

### Instructions for setting up a Scylla Cluster from this repo

```
cd mms2
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

### Destroying the Scylla Cluster 
```
cd mms2
docker-compose kill
docker-compose rm -f
```
### Importing the MMS keyspaces and data automatically 

```
docker exec scylla-node1 cqlsh -f /mutant-data.txt
```

Then re-run docker-compose:
```
docker-compose kill
docker-compose rm -f
docker-compose up -d
```
The data will be imported about 60 seconds after the containers come up.

