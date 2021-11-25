Prepared statements spring demo on top of default Spring Boot

After this is run, you will have a REST API server
listening on :8080

MonsterController lists the respective endpoints

Expects a Scylla DB or Cassandra DB running on
localhost : 9042
ev. with cassandra/cassandra auth
AND with schema loaded from `./schema.cql`

Make sure to adjust src/resources/application.properties , if you will use different Scylla cluster

Check `./start-scylla-container.sh` script that can help you run a ScyllaDB single VM

Import to your local Postman ( https://www.postman.com/ ) app a postman collection v 2.1 from:
`./Springdemo-default.postman_collection.json`
to run sample queries against REST API

Using Scylla driver is commented out, since this is default demo
https://java-driver.docs.scylladb.com/stable/