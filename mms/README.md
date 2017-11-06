## Scylla in Docker for the Mutant Monitoring Blog Series

### Instructions on setting up a Scylla Cluster from this repo

```
cd mms
docker-compose up -d
docker exec -it docker exec -it mms_scylla-node1_1 sh
```
### Destroying the Scylla Cluster 
```
cd mms
docker-compose kill
docker-compose rm -f
```