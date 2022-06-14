## Scylla Manager running in Docker 

### Instructions for setting up Scylla Manager from this repo. For more details read the documentation here: https://hub.docker.com/r/scylladb/scylla-manager and also follow the Scylla University lessons here: https://university.scylladb.com/courses/scylla-operations/

```
cd manager
```
Build an image of Scylla node with Scylla Manager Agent installed
```
docker-compose build
```

Start the services (Minio, Scylla cluster, Scylla single node for Scylla manager backend,Scylla manager)
```
docker-compose up -d
```

Setup a bucket in Minio:
```
docker-compose exec minio mkdir /data/docker
```

Wait until Scylla cluster boots, it may take several minutes. Check the status with
```
docker-compose exec scylla-node1 nodetool status
```

Add the cluster to Scylla Manager:
```
docker-compose exec scylla-manager sctool cluster add --name test --host=scylla-node1 --auth-token=token
```

Check cluster status in Scylla Manager:
```
docker-compose exec scylla-manager sctool status -c test
```

Launch backup to minio
```
docker-compose exec scylla-manager sctool backup -c test --location s3:docker
```

Check backup status
```
docker-compose exec scylla-manager sctool task list
```


### Shutting down all services 
```
docker-compose down
```
