# Scylla Rust Driver 

This lesson covers more . These topics will be explained and demonstrated using the Scylla Rust driver.
An example application that demonstrates advanced topics such as prepared statements, paging, and retries using the Scylla Rust Driver. More info in the Scylla University Course [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/).

### Starting a Scylla Cluster

To get Scylla up and running start a local scylla instance on port 9042:

```bash
docker run   -p 9042:9042/tcp   --name some-scylla   --hostname some-scylla   -d scylladb/scylla:4.5.0    --smp 1 --memory=750M --overprovisioned 1
```

### Running the RUST Application

The application uses [scylla-rust-driver](https://github.com/scylladb/scylla-rust-driver) which is an open-source Scylla driver for Rust.
If you don’t already have Rust and Cargo installed, go ahead and install it using the rustup.rs toolchain:

```bash
cd scylla-code-samples/Rust_Scylla_Driver/ps-logger
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

First create the keyspace and table in cqlsh:

```bash
CREATE KEYSPACE IF NOT EXISTS log WITH REPLICATION = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};
```


```bash
CREATE TABLE IF NOT EXISTS log.messages (
  id bigint,
  message text,
  PRIMARY KEY (id)
);
```


The application reads all the lines from stdin, writes them into the database, and prints them back. Run the app, providing an input line.

```bash
echo 'this is a message' | cargo run
```


### Destroying the Scylla Cluster

docker stop some-scylla
docker rm some-scylla
