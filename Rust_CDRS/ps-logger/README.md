# Scylla Rust Driver CDRS 
Instructions for setting up a one node Scylla cluster in Docker and running an example RUST application that interacts with the cluster and performs simple queries.  More info in the Scylla University Course [Using Scylla Drivers](https://university.scylladb.com/courses/using-scylla-drivers/). 

### Starting a Scylla Cluster
To get Scylla up and running start a local scylla instance on port 9042:
```bash
docker run   -p 9042:9042/tcp   --name some-scylla   --hostname some-scylla   -d scylladb/scylla:4.4.0    --smp 1 --memory=750M --overprovisioned 1
```

### Running the RUST Application
The application uses [CDRS](https://github.com/AlexPikalov/cdrs) which is an open-source Scylla driver for Rust. 
If you don’t already have Rust and Cargo installed, go ahead and install it using the rustup.rs toolchain:
```bash
cd scylla-code-samples/rust/ps-logger
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```
The application will be able to store and query temperature time-series data. Each measurement will contain the following information:
* The sensor ID for the sensor that measured the temperature
* The time the temperature was measured
* The temperature value 

It will connect to the Scylla cluster, create a keyspace and a table, insert two rows into the created table and read those two rows from the database. 
Run the code:
```bash
$ cargo run
```
### Destroying the Scylla Cluster
docker-compose kill
docker-compose rm -f

