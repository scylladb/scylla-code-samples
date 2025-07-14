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
    val connection: CassandraConnection = ContactPoints(Seq("localhost"))
      .keySpace("catalog")
    val db = new MutantsDatabase(connection)
    val svc = new MutantsService(db)

    println("Successfully connected to ScyllaDB database!")
    
    Await.result(
      for {
        _ <- svc.getAll().andThen {
          case Success(mutants) =>
            println("Initial Mutants: " + mutants.mkString(", "))
        }
        _ <- svc.insertMutant(
          Mutant(
            "Miles",
            "Morales", 
            "42 Brooklyn St",
            "https://www.facebook.com/miles-morales"
          )
        )
        _ <- svc.getAll().andThen {
          case Success(mutants) =>
            println("Mutants after INSERT: " + mutants.mkString(", "))
        }
      } yield (),
      30.seconds
    )

    db.shutdown()
  }
} 