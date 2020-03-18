## Scylla Manager running in Docker 

### Instructions for setting up Scylla Manager from this repo. For more details read the documentation here: https://hub.docker.com/r/scylladb/scylla-manager and also follow the Scylla University lessons here: https://university.scylladb.com/courses/scylla-operations/

```
cd manager
```

Start MinIO in a container:
```
docker run -d -p 9000:9000 --name minio1 \
    -e "MINIO_ACCESS_KEY=minio" \
    -e "MINIO_SECRET_KEY=minio123" \
    -v /mnt/data:/data minio/minio:RELEASE.2020-03-14T02-21-58Z server /data

```

Create a regular ScyllaDB image with a Scylla Manager Agent to allow for proper communication between ScyllaDB and Scylla Manager:

```
docker build -t scylladb/scylla-with-agent .
```

Create a new ScyllaDB instance using the image you just built:
```
docker run -d --name scylla --link minio1 --mount type=volume,source=scylla_db_data,target=/var/lib/scylla scylladb/scylla-with-agent --smp 1 --memory=1G
```

Start a regular ScyllaDB instance that Scylla Manager will use to store it's internal data in with the following command:
```
docker run -d --name scylla-manager-db --mount type=volume,source=scylla_manager_db_data,target=/var/lib/scylla scylladb/scylla --smp 1 --memory=1G
```

Finally start Scylla manager using the following command. We need to link this instance to both of the ScyllaDB instances:
```
docker run -d --name scylla-manager --link scylla-manager-db --link scylla scylladb/scylla-manager:2.0.1
```



### Destroying the Scylla Cluster 
List the running containers
```
docker ps -a
```

To stop the containers, for each created one run
```
docker stop <Container ID>
```

To remove the containers for each one run
```
docker stop <Container ID>
```


