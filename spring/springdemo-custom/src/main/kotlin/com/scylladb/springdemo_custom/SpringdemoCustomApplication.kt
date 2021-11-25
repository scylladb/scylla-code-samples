package com.scylladb.springdemo_custom

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

/**
 * Starts the application.
 *
 *
 * This application assumes that a ScyllaDB or Apache Cassandra cluster is
 * running and accepting client connections.
 *
 *
 * The connection properties can be configured in the application.yml file.
 *
 *
 * The application assumes that a keyspace `springdemo` and a table `springdemo.stocks` both
 * exist with the following schema (see schema.cql for source of truth):
 *
 * <pre>`CREATE KEYSPACE IF NOT EXISTS springdemo
 * WITH replication = {'class':'NetworkTopologyStrategy', 'replication_factor':1}
 * AND durable_writes = false;
 * CREATE TABLE IF NOT EXISTS springdemo.stocks
 * (symbol text, date timestamp, value decimal, PRIMARY KEY (symbol, date))
 * WITH CLUSTERING ORDER BY (date DESC);
`</pre> *
 */

//@SpringBootApplication
// scan below is very important to match location of common/conf to find the configuration classes
@SpringBootApplication(scanBasePackages = ["com.scylladb.springdemo_custom"])
class SpringdemoCustomApplication

fun main(args: Array<String>) {
    runApplication<SpringdemoCustomApplication>(*args)
}
