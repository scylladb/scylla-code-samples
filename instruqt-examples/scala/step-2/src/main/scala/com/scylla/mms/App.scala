package com.scylla.mms

import com.outworkers.phantom.dsl._
import com.scylla.mms.cql.MutantsDatabase
import com.scylla.mms.model.Mutant
import com.scylla.mms.service.MutantsService

import scala.concurrent.Await
import scala.concurrent.duration._
import scala.util.Success

/**
 * Main application for the Mutant Management System
 * Step 2: Read operations - show existing mutant data
 */
object App {
  def main(args: Array[String]): Unit = {
    val connection: CassandraConnection =
      ContactPoints(List("localhost"))
        .keySpace("catalog")
    val db = new MutantsDatabase(connection)
    val svc = new MutantsService(db)

    if (db.session != null) {
      println("Successfully connected to ScyllaDB database!")
    } else {
      println("Failed to connect to ScyllaDB database.")
    }

    // Show existing mutant data
    Await.result(
      svc.getAll().andThen {
        case Success(mutants) =>
          println("Data that we have in the catalog".center(50, "="))
          mutants.foreach(mutant => println(s"${mutant.firstName} ${mutant.lastName}"))
      },
      30.seconds
    )

    db.shutdown()
  }
}
