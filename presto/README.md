# Presto in Docker with Jaeger and Metabase

This sample contains a docker-compose.yml and Presto configs for running Presto in Docker with Jaeger, Metabase and ScyllaDB.

The following example uses Jaeger HotRod sample application as data producer which sends traces to Jaeger collector. 
Jaeger collector stores traces in ScyllaDB. Presto is used to query traces from ScyllaDB and 
Metabase is used to visualize the data.

**Prerequisites**
- [docker installed](https://docs.docker.com/engine/install/)

Instructions
============

**Procedure**
1. Run `docker-compose up -d` to start the containers
2. Wait for about minute for ScyllaDB to start and Metabase to initialize.
3. Open Jaeger HotRod sample application at http://localhost:8081 and click on buttons to generate traces.
4. Open Metabase at http://localhost:3000 and complete admin onboarding.
5. Add Presto as a data source in Metabase. 
Use `http://presto:8080` as a host and `scylladb` as a catalog name. 
During filling presto connection details fill `Username` with arbitrary string 
and leave user `Password` empty.
6. Observe traces insights in Metabase.

**Cleanup**
1. Run `docker-compose down --volumes` to stop and remove the containers and created volumes