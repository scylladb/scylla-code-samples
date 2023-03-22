To learn more see the [Spring Boot, ScyllaDB, and Time Series Data lesson](https://university.scylladb.com/courses/the-mutant-monitoring-system-training-course/lessons/spring-boot-scylladb-and-time-series-data/) on ScyllaDB University.

Prepared statements spring demo on top of Scylla driver

This demo expects JDK 17 to be used.
Components used for testing:
Scylla 4.4.6 on local docker
Scylla driver 4.13
Spring Boot 2.6.0
Kotlin 1.6
JDK 17
Gradle 7.3
run from Idea 2021.2.3 CE

After this is run using `bootRun` gradle target, you will have a REST API server
listening on :8082

AsyncStockController lists the respective endpoints

This demo is heavily inspired by
https://github.com/DataStax-Examples/cassandra-reactive-demo-java/
which was rewritten to kotlin.

Using Scylla driver
https://java-driver.docs.scylladb.com/stable/

Expects a Scylla or Apache Cassandra running on
localhost : 9042
ev. with cassandra/cassandra auth
AND with schema loaded from `./schema.cql`

Make sure to adjust src/resources/application.yml , if you will use a different Scylla cluster

Check `./start-scylla-container.sh` script that can help you run a ScyllaDB single VM

Import to your local Postman ( https://www.postman.com/ ) app a postman collection v 2.1
`./Springdemo-prepared.postman_collection.json`
to run sample queries against REST API

Requests are prepared - hence routed to appropriate node and thanks to scylla driver also directly to appropriate (cpu) shard.

