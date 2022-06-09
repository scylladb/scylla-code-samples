# Scylla Rust Driver 

This lesson covers more. These topics will be explained and demonstrated using the Scylla Rust driver.
An example application that demonstrates advanced topics such as prepared statements, paging, and retries using the Scylla Rust Driver. More info in the Scylla University Course [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/).

### Starting a Scylla Cluster

To get Scylla up and running start a local scylla instance on port 9042:

```bash
docker run   -p 9042:9042/tcp   --name some-scylla   --hostname some-scylla   -d scylladb/scylla:4.5.0    --smp 1 --memory=750M --overprovisioned 1
```

### Running the Rust Application

The application uses [scylla-rust-driver](https://github.com/scylladb/scylla-rust-driver) which is an open-source Scylla driver for Rust.
If you don’t already have Rust and Cargo installed, go ahead and install it using the rustup.rs toolchain:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

The application reads all the lines from stdin, writes them into the database, and prints them back. Run the app, providing an input line.

```bash
echo 'this is a message' | cargo run
```


### Destroying the Scylla Cluster

docker stop some-scylla
docker rm some-scylla
