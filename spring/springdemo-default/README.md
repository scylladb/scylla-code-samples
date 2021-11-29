Prepared statements spring demo on top of default Spring Boot

This demo expects JDK 11 to be used.
Components used for testing:
Scylla 4.4.6 on local docker
Scylla driver 4.13
Spring Boot 2.6.0
Kotlin 1.6
JDK 11
Gradle 7.2
run from Idea 2021.2.3 CE

After this is run using `bootRun` gradle target, you will have a REST API server
listening on :8080

MonsterController lists the respective endpoints

Expects a Scylla or Apache Cassandra running on
localhost : 9042
ev. with cassandra/cassandra auth
AND with schema loaded from `./schema.cql`

Make sure to adjust src/resources/application.properties , if you will use a different Scylla cluster

Check `./start-scylla-container.sh` script that can help you run a ScyllaDB single VM

Import to your local Postman ( https://www.postman.com/ ) app a postman collection v 2.1 from:
`./Springdemo-default.postman_collection.json`
to run sample queries against REST API

Using Scylla driver is commented out, since this is default demo
https://java-driver.docs.scylladb.com/stable/