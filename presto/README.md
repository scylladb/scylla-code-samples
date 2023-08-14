# Presto in Docker with Jaeger and Metabase

This sample contains a docker-compose.yml and Presto configs for running Presto in Docker with  Metabase and ScyllaDB.

The following example uses simple schema and data for online merch store in ScyllaDB. Presto is used to query data from ScyllaDB and 
Metabase is used to visualize the data.

**Prerequisites**
- [docker installed](https://docs.docker.com/engine/install/)

Instructions
============

**Procedure**
1. Run `docker-compose up -d` to start the containers
2. Wait for about minute for ScyllaDB to start and Metabase to initialize.
4. Generate schema and data: `make prepare_data`. 
4. Open Metabase at http://localhost:3000 and complete admin onboarding.
5. Add Presto as a data source in Metabase. 
Use `presto` as a host, `8080` as a port, `scylladb` as a catalog name and `merch_store` as schema name. 
During filling presto connection details fill `Username` with arbitrary string 
and leave user `Password` empty.
6. Observe goods, users and transaction insights in Metabase. For example from home screen do:
    * Click on "Browse data" button
    * Choose created Presto data source
    * Select merch_store schema
    * Open Transactions table
    * On the right top Click green "Summarize" button
    * Select Group By "Transaction Date" and Sum by "Total Amount"
    * Save "Question"

**Cleanup**
1. Run `docker-compose down --volumes` to stop and remove the containers and created volumes
