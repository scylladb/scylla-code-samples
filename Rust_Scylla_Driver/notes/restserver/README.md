# Rust Demo - Note REST API app on top of ScyllaDB

This repo contains a real world example of a full blown application which showcases the following capabilities:
- Creating fast REST APIs using [Actix Web Framework](https://actix.rs/)
- Data ingestion and reads to/from  [ScyllaDB](https://www.scylladb.com/) (Cassandra compatible).
- Writing highly async concurrent applications using [Tokio](https://tokio.rs/)

## Use Case

This repo presents the following use case:

- Simple Note taking REST API server written in Rust

The application has a REST API to trigger the ingest process and also to get a node and traverse a node.

The ingestion process will read files from a S3 bucket, process them and store them into ScyllaDB.

## Goals

update dependencies from Cargo.toml with:
`cargo update`

build with:
`cargo build --color=always --message-format=json-diagnostic-rendered-ansi --all --all-targets`

run using:
`cargo run --color=always --package restserver-notes --bin restserver-notes`

## REST API

File [/Note rust app.postman_collection.json](/Note rust app.postman_collection.json)
- contains postman (http://www.postman.com) collection of testing queries and simple API description re parameters and body

## Env Vars

- `PORT`: Port to run the REST API.
- `REGION`: AWS Region where the bucket is located.
- `RUST_LOG`: Log level
- `DB_URL`: ScyllaDB URL, for example `localhost:9042`.
- `DB_DC`: ScyllaDB DC, for example `datacenter1`.
- `DB_USER`: ScyllaDB user name, for example `cassandra`.
- `DB_PASSWORD`: ScyllaDB users password, for example `cassandra`. 
- `PARALLEL_INSERTS`: How many add note REST API calls can be done in parallel
- `DB_PARALLELISM`: Parallelism for the database, number of threads that will be running inserts in parallel. ScyllaDB can support hundreds or even thousands of them.
- `SCHEMA_FILE`: Location of the schema, for example `schema/ddl.sql`

## Data Model

You can find the DDL in [/schema/ddl.sql](/schema/ddl.sql).
Note - it is OK for single person, but otherwise this won't scale, look at notebooks implementation and try to give it a
good thought - goal is to have high cardinality - so all Scylla cpus can work hard in parallel.

PK cardinality == all cpus used (PKs are distributed to cpus using murmur3 hash)
PK+CK cardinality might result in having too many rows to belong to single cpu, hence creating too many CKs for 
single PK is an anti-pattern (that said Scylla can handle it till 100 000 rows per partition) 
