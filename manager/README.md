## ScyllaDB Manager running in Docker

### Instructions for setting up ScyllaDB Manager from this repo. For more details read the documentation here: https://hub.docker.com/r/scylladb/scylla-manager and also follow the ScyllaDB University lessons here: https://university.scylladb.com/courses/scylla-operations/

```
cd manager
```
Build an image of ScyllaDB node with ScyllaDB Manager Agent installed
```
docker compose build
```

Start the services (Minio, ScyllaDB cluster, ScyllaDB single node for ScyllaDB Manager backend, ScyllaDB Manager)
```
docker compose up -d
```

Setup a bucket in Minio:
```
docker compose exec minio mkdir /data/docker
```

Wait until the ScyllaDB cluster boots (may take several minutes). Check the status with:
```
docker compose exec scylla-node1 nodetool status
```

Add the cluster to ScyllaDB Manager:
```
docker compose exec scylla-manager sctool cluster add --name test --host=scylla-node1 --auth-token=token
```

Check cluster status in ScyllaDB Manager:
```
docker compose exec scylla-manager sctool status -c test
```

Launch a backup to minio:
```
docker compose exec scylla-manager sctool backup -c test --location s3:docker
```

Check task list:
```
docker compose exec scylla-manager sctool tasks -c test
```


### Shutting down all services
```
docker compose down
```
