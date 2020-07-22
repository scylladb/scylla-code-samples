Care Pet ScyllaDB IoT example
===

This is an example project that demonstrates a generic IoT use case
for ScyllaDB in Go.

The application allows tracking of pets health indicators
and consist of 3 parts:

- migrate (`/cmd/migrate`) - creates `carepet` keyspace and tables
- collar (`/cmd/sensor`) - generates a pet health data and pushes it into the storage
- web app (`/cmd/server`) - REST API service for tracking pets health state

Quick Start
---

Prerequisites:

- [go](https://golang.org/dl/) at least 1.14
- [docker](https://www.docker.com/)
- [docker-compose](https://docs.docker.com/compose/)

To run local ScyllaDB cluster consisting of 3 nodes with
the help of `docker` and `docker-compose` execute:

    $ docker-compose up -d

Docker compose will spin up 3 nodes: `carepet-scylla1`, `carepet-scylla2`
and `carepet-scylla3`. You can access them with the `docker` command:

    to execute CQLSH:
    $ docker exec -it carepet-scylla1 cqlsh

    to execute nodetool:
    $ docker exec -it carepet-scylla1 nodetool status

    shell:
    $ docker exec -it carepet-scylla1 shell

You can inspect any node by means of the `docker inspect` command
as follows:

    for example:
    $ docker inspect carepet-scylla1

    to get node IP address run:
    $ docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' carepet-scylla1

To initialize database execute:

    $ go build ./cmd/migrate
    $ NODE1=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' carepet-scylla1)
    $ ./migrate --hosts $NODE1

    expected output:

    2020/08/06 16:43:01 Bootstrap database...
    2020/08/06 16:43:13 Keyspace metadata = {Name:carepet DurableWrites:true StrategyClass:org.apache.cassandra.locator.NetworkTopologyStrategy StrategyOptions:map[datacenter1:3] Tables:map[gocqlx_migrate:0xc00016ca80 measurement:0xc00016cbb0 owner:0xc00016cce0 pet:0xc00016ce10 sensor:0xc00016cf40 sensor_avg:0xc00016d070] Functions:map[] Aggregates:map[] Types:map[] Indexes:map[] Views:map[]}

You can check the database structure with:

    $ docker exec -it carepet-scylla1 cqlsh
    cqlsh> DESCRIBE KEYSPACES

    carepet  system_schema  system_auth  system  system_distributed  system_traces

    cqlsh> USE carepet;
    cqlsh:carepet> DESCRIBE TABLES

    pet  sensor_avg  gocqlx_migrate  measurement  owner  sensor

    cqlsh:carepet> DESCRIBE TABLE pet

    CREATE TABLE carepet.pet (
        owner_id uuid,
        pet_id uuid,
        address text,
        age int,
        name text,
        weight float,
        PRIMARY KEY (owner_id, pet_id)
    ) WITH CLUSTERING ORDER BY (pet_id ASC)
        AND bloom_filter_fp_chance = 0.01
        AND caching = {'keys': 'ALL', 'rows_per_partition': 'ALL'}
        AND comment = ''
        AND compaction = {'class': 'SizeTieredCompactionStrategy'}
        AND compression = {'sstable_compression': 'org.apache.cassandra.io.compress.LZ4Compressor'}
        AND crc_check_chance = 1.0
        AND dclocal_read_repair_chance = 0.1
        AND default_time_to_live = 0
        AND gc_grace_seconds = 864000
        AND max_index_interval = 2048
        AND memtable_flush_period_in_ms = 0
        AND min_index_interval = 128
        AND read_repair_chance = 0.0
        AND speculative_retry = '99.0PERCENTILE';

    cqlsh:carepet> exit

To start pet collar simulation execute the following in the separate terminal:

    $ go build ./cmd/sensor
    $ NODE1=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' carepet-scylla1)
    $ ./sensor --hosts $NODE1

    expected output:

    2020/08/06 16:44:33 Welcome to the Pet collar simulator
    2020/08/06 16:44:33 New owner # 9b20764b-f947-45bb-a020-bf6d02cc2224
    2020/08/06 16:44:33 New pet # f3a836c7-ec64-44c3-b66f-0abe9ad2befd
    2020/08/06 16:44:33 sensor # 48212af8-afff-43ea-9240-c0e5458d82c1 type L new measure 51.360596 ts 2020-08-06T16:44:33+02:00
    2020/08/06 16:44:33 sensor # 2ff06ffb-ecad-4c55-be78-0a3d413231d9 type R new measure 36 ts 2020-08-06T16:44:33+02:00
    2020/08/06 16:44:33 sensor # 821588e0-840d-48c6-b9c9-7d1045e0f38c type L new measure 26.380281 ts 2020-08-06T16:44:33+02:00
    ...

Write down the pet Owner ID (ID is something after the `#` sign without trailing spaces).

To start REST API service execute the following in the separate terminal:

    $ go build ./cmd/server
    $ NODE1=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' carepet-scylla1)
    $ ./server --port 8000 --hosts $NODE1

    expected output:

    2020/08/06 16:45:58 Serving care pet at http://127.0.0.1:8000

Now you can open `http://127.0.0.1:8000/` in the browser or send an HTTP request from the CLI:

    $ curl -v http://127.0.0.1:8000/

    expected output:

    > GET / HTTP/1.1
    > Host: 127.0.0.1:8000
    > User-Agent: curl/7.71.1
    > Accept: */*
    >
    * Mark bundle as not supporting multiuse
    < HTTP/1.1 404 Not Found
    < Content-Type: application/json
    < Date: Thu, 06 Aug 2020 14:47:41 GMT
    < Content-Length: 45
    < Connection: close
    <
    * Closing connection 0
    {"code":404,"message":"path / was not found"}

This is ok. If you see this JSON in the end with 404 it means everything works as expected.

To read an owner data you can use saved `owner_id` as follows:

    $ curl -v http://127.0.0.1:8000/api/owner/{owner_id}

    for example:

    $ curl http://127.0.0.1:8000/api/owner/a05fd0df-0f97-4eec-a211-cad28a6e5360

    expected result:

    {"address":"home","name":"gmwjgsap","owner_id":"a05fd0df-0f97-4eec-a211-cad28a6e5360"}

To list the owners pets use:

    $ curl -v http://127.0.0.1:8000/api/owner/{owner_id}/pets

    for example:

    $ curl http://127.0.0.1:8000/api/owner/a05fd0df-0f97-4eec-a211-cad28a6e5360/pets

    expected output:

    [{"address":"home","age":57,"name":"tlmodylu","owner_id":"a05fd0df-0f97-4eec-a211-cad28a6e5360","pet_id":"a52adc4e-7cf4-47ca-b561-3ceec9382917","weight":5}]

To list pet's sensors use:

    $ curl -v curl -v http://127.0.0.1:8000/api/pet/{pet_id}/sensors

    for example:

    $ curl http://127.0.0.1:8000/api/pet/cef72f58-fc78-4cae-92ae-fb3c3eed35c4/sensors

    [{"pet_id":"cef72f58-fc78-4cae-92ae-fb3c3eed35c4","sensor_id":"5a9da084-ea49-4ab1-b2f8-d3e3d9715e7d","type":"L"},{"pet_id":"cef72f58-fc78-4cae-92ae-fb3c3eed35c4","sensor_id":"5c70cd8a-d9a6-416f-afd6-c99f90578d99","type":"R"},{"pet_id":"cef72f58-fc78-4cae-92ae-fb3c3eed35c4","sensor_id":"fbefa67a-ceb1-4dcc-bbf1-c90d71176857","type":"L"}]

To review the pet's sensors data use:

    $ curl http://127.0.0.1:8000/api/sensor/{sensor_id}/values?from=2006-01-02T15:04:05Z07:00&to=2006-01-02T15:04:05Z07:00

    for example:

    $  curl http://127.0.0.1:8000/api/sensor/5a9da084-ea49-4ab1-b2f8-d3e3d9715e7d/values\?from\="2020-08-06T00:00:00Z"\&to\="2020-08-06T23:59:59Z"

    expected output:

    [51.360596,26.737432,77.88015,...]

To read the pet's daily average per sensor use:

    $ curl http://127.0.0.1:8000/api/sensor/{sensor_id}/values/day/{date}

    for example:

    $ curl -v http://127.0.0.1:8000/api/sensor/5a9da084-ea49-4ab1-b2f8-d3e3d9715e7d/values/day/2020-08-06

    expected output:

    [0,0,0,0,0,0,0,0,0,0,0,0,0,0,42.55736]

Structure
---

Package structure is as follows:

| Name         | Purpose                                   |
| ----         | -------                                   |
| /api         | swagger api spec                          |
| /cmd         | applications executables                  |
| /cmd/migrate | install database schema                   |
| /cmd/sensor  | simulate pet collar                       |
| /cmd/server  | web application backend                   |
| /config      | database configuration                    |
| /db          | database handlers (gocql/x)               |
| /db/cql      | database schema                           |
| /handler     | swagger REST API handlers                 |
| /model       | application models and ORM metadata       |

API
---

Swagger [specification](api/api.json).

Implementation
---

Collars are small devices that attach to pets and collect data
with the help of different sensors. After data collected it
may be delivered to the central database for the analysis and
health status checking.

Collar code sits in the `/cmd/sensor` and uses `scylladb/gocqlx`
Go driver to connect to the database directly and publish its data.
Collar sends sensor measurements updates every once in a second.

Overall all applications in this repository use `scylladb/gocqlx` for:

- Relational Object Mapping (ORM)
- Build Queries
- Migrate database schemas

Web application REST API server resides in `/cmd/server` and uses
`go-swagger` that supports OpenAPI 2.0 to expose its API. API
handlers reside in `/handler`. Most of the queries are reads.

The application is capable of caching sensor measurements data
on hourly basis. It uses lazy evaluation to manage `sensor_avg`.
It can be viewed as an application-level lazy-evaluated
materialized view.

The algorithm is simple and resides in `/handler/avg.go`:

- read `sensor_avg`
- if no data, read `measurement` data, aggregate in memory, save
- serve request

Architecture
---

    Pet --> Sensor --> ScyllaDB <-> REST API Server <-> User

How to start new project with Go
---

Install Go. Create a repository. Clone it. Execute inside of
your repository:

    $ go mod init github.com/my_name/my_module

Now when you have your go module spec connect ScyllaDB Go
driver as a dependency with:

    $ go get -u github.com/scylladb/gocqlx/v2

Now your `go.mod` will be looking something like this:

    module github.com/blah/blah

    go 1.14

    require (
        github.com/gocql/gocql v0.0.0-20200624222514-34081eda590e // indirect
        github.com/scylladb/gocqlx/v2 v2.1.0 // indirect
    )

Add a `gocql` driver replacement with our epic version with:

    replace github.com/gocql/gocql => github.com/scylladb/gocql v1.4.0

Now `go.mod` must look like:

    module github.com/blah/blah

    go 1.14

    require (
        github.com/gocql/gocql v0.0.0-20200624222514-34081eda590e // indirect
        github.com/scylladb/gocqlx/v2 v2.1.0 // indirect
    )

    replace github.com/gocql/gocql => github.com/scylladb/gocql v1.4.0

Now you are ready to connect to the database and start working.

To connect to the database do the following:

```go
import (
	"github.com/gocql/gocql"
	"github.com/scylladb/gocqlx/v2"
)

var	cfg *gocql.ClusterConfig = gocql.NewCluster()

cfg.Hosts = []string{"127.0.0.1"}
cfg.Keyspace = "my_keyspace"

ses := gocqlx.WrapSession(gocql.NewSession(cfg))
```

Now you can issue CQL commands:

```go
iter := ses.Session.Query("SELECT name FROM hello").Iter()

for {
    var t string
    if !iter.Scan(&t) {
        break
    }
}

if err := iter.Close(); err != nil {
    ...
}
```

Or save models:

```go
var owner model.Owner

if err := db.TableOwner.GetQuery(ses).Bind(id).GetRelease(&owner); err == gocql.ErrNotFound {
    ...
} else if err != nil {
    ...
}
```

For greater details check out `/handler`, `/db` and `/config` packages.

Links
---

- https://hub.docker.com/r/scylladb/scylla/
- https://github.com/scylladb/gocqlx
