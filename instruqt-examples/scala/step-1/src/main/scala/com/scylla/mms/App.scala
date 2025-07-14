package com.scylla.mms

import com.outworkers.phantom.dsl._
import com.scylla.mms.cql.MutantsDatabase

import scala.concurrent.Await
import scala.concurrent.duration._

/**
 * Main application for the Mutant Management System
 * Step 1: Basic database connection
 */
object App {
  def main(args: Array[String]): Unit = {
    val connection: CassandraConnection =
      ContactPoints(List("localhost"))
        .keySpace("catalog")
    val db = new MutantsDatabase(connection)
    
    // Test connection
    if (db.session != null) {
      println("Successfully connected to ScyllaDB database!")
    } else {
      println("Failed to connect to ScyllaDB database.")
    }

    db.shutdown()
  }
}
