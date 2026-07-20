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

Setup a bucket in Minio (required before running backups):
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

### Setting up ScyllaDB Monitoring (optional)

Clone the monitoring repo and set it up alongside the manager stack.

Get the IP addresses of the ScyllaDB nodes and the Manager container:
```
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' scylla-node1 scylla-node2 scylla-node3
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' manager-scylla-manager-1
```

Clone scylla-monitoring:
```
git clone https://github.com/scylladb/scylla-monitoring.git
cd scylla-monitoring
```

Create `prometheus/scylla_servers.yml` with the ScyllaDB node IPs (without port — port 9180 is added automatically):
```yaml
- targets:
    - <scylla-node1-ip>
    - <scylla-node2-ip>
    - <scylla-node3-ip>
  labels:
    cluster: cluster1
    dc: datacenter1
```

Create `prometheus/scylla_manager_servers.yml` with the Manager IP:
```yaml
- targets:
  - <manager-ip>:5090
```

Generate dashboards and start the stack (replace `2026.2` with your ScyllaDB version, `manager_public` is the Docker network created by the manager compose):
```
./generate-dashboards.sh -F -v 2026.2
./start-all.sh -v 2026.2 -M 3 -D "--net=manager_public" --no-loki
```

Browse to http://localhost:3000 for the Grafana dashboard.

**Note for Linux with SELinux (e.g. Fedora/RHEL):** The prometheus target files must be accessible to the container. Run:
```
chcon -t container_file_t prometheus/scylla_servers.yml prometheus/scylla_manager_servers.yml
```
Then reload Prometheus: `curl -X POST http://localhost:9090/-/reload`


### Shutting down all services
```
docker compose down
```
