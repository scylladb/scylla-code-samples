## Presto in Docker for the Mutant Monitoring Blog Series

### Prerequisites ###

1. A Scylla Cluster up and running with data imported from the [MMS Blog Series](http://www.scylladb.com/tag/mms/).

2. [Docker](https://docs.docker.com/engine/installation/).

3. This [repository](https://github.com/scylladb/scylla-code-samples) cloned on your machine.

### Building and Running the Container

```
cd scylla-code-samples/mms/presto
docker build -t presto .
docker run --name presto --network mms_web -p 8080:8080 -d presto
```

### Accessing the Presto Web Interface

Navigate to [http://127.0.0.1:8080](http://127.0.0.1:8080) in your web browser.

### Running Queries from Scylla from the Presto Container
```
docker exec -it presto bash
./presto-cli.jar --catalog cassandra

use catalog;
select * from mutant_data where first_name like 'Bob';
```