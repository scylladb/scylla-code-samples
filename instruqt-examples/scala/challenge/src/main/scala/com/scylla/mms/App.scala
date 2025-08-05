package com.scylla.mms

import com.outworkers.phantom.dsl._
import com.scylla.mms.cql.MutantsDatabase
import com.scylla.mms.model.Mutant
import com.scylla.mms.service.MutantsService

import scala.concurrent.Await
import scala.concurrent.duration._
import scala.util.Success


object App {
  def main(args: Array[String]): Unit = {
    val connection: CassandraConnection =
      ContactPoints(List("localhost"))
        .keySpace("catalog")
    val db = new MutantsDatabase(connection)
    val svc = new MutantsService(db)

    if (db.session != null) {
      println("Successfully connected to the ScyllaDB databasebase!")
    } else {
      println("Failed to connect to ScyllaDB database.")
    }

    Await.result(
      for {
        // Show existing data
        _ <- svc.getAll().andThen {
          case Success(mutants) =>
            println("=" * 25 + " Data that we have in the catalog " + "=" * 25)
            mutants.foreach(mutant => println(s"${mutant.firstName} ${mutant.lastName}"))
        }
        // Add new mutant
        _ <- svc.insertMutant(
          Mutant(
            "Peter",
            "Parker",
            "1515 Main St",
            "https://tinyurl.com/peterparker123"
          )
        ).andThen {
          case Success(_) =>
            println("\nAdding Peter Parker...")
            println("Added.\n")
        }
        // Show data after insertion
        _ <- svc.getAll().andThen {
          case Success(mutants) =>
            println("=" * 25 + " Data after adding Peter Parker " + "=" * 25)
            mutants.foreach(mutant => println(s"${mutant.firstName} ${mutant.lastName}"))
        }
        // Delete Peter Parker
        _ <- svc.deleteMutant().andThen { // TODO: fix this line
          case Success(_) =>
            println("\nDeleting Peter Parker...")
            println("Deleted.\n")
        }
        // Show data after deletion
        _ <- svc.getAll().andThen {
          case Success(mutants) =>
            println("=" * 25 + " Data after deleting Peter Parker " + "=" * 25)
            mutants.foreach(mutant => println(s"${mutant.firstName} ${mutant.lastName}"))
        }
      } yield (),
      30.seconds
    )

    db.shutdown()
  }
}
