# Scylla Rust Driver CDRS 
Instructions for setting up a one node Scylla cluster in Docker and running an example RUST application that interacts with the cluster and performs simple queries.  More info in the Scylla University Course [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/). 

### Starting a Scylla Cluster
To get Scylla up and running start a local scylla instance on port 9042:
```bash
docker run   -p 9042:9042/tcp   --name some-scylla   --hostname some-scylla   -d scylladb/scylla:3.3.0    --smp 1 --memory=750M --overprovisioned 1
```

### Running the RUST Application
The application uses [CDRS](https://github.com/AlexPikalov/cdrs) which is an open-source Scylla driver for Rust. 
If you don’t already have Rust and Cargo installed, go ahead and install it using the rustup.rs toolchain:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
Then run the code:
```bash
$ cargo run
```
### Destroying the Scylla Cluster
docker-compose kill
docker-compose rm -f

