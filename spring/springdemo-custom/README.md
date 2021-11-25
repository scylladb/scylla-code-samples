Prepared statements spring demo on top of Scylla driver

After this is run, you will have a REST API server
listening on :8082

AsyncStockController lists the respective endpoints

This demo is heavily inspired by
https://github.com/DataStax-Examples/cassandra-reactive-demo-java/
which was rewritten to kotlin.

Using Scylla driver
https://java-driver.docs.scylladb.com/stable/

Expects a Scylla DB or Cassandra DB running on
localhost : 9042
ev. with cassandra/cassandra auth
AND with schema loaded from `./schema.cql`

Make sure to adjust src/resources/application.yml , if you will use different Scylla cluster

Check `./start-scylla-container.sh` script that can help you run a ScyllaDB single VM

Import to your local Postman ( https://www.postman.com/ ) app a postman collection v 2.1
`./Springdemo-custom.postman_collection.json`
to run sample queries against REST API

Request are prepared - hence routed to appropriate node and (cpu) shard thanks to scylla driver.

