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
      ContactPoints(List("scylla-node1", "scylla-node2", "scylla-node3"))
        .keySpace("catalog")
    val db = new MutantsDatabase(connection)
    val svc = new MutantsService(db)

    Await.result(
      for {
        _ <- svc.getAll().andThen {
          case Success(mutants) =>
            println(s"Mutants: ${mutants.mkString(", ")}")
        }
        _ <- svc.insertMutant(
          Mutant(
            "Mike",
            "Tyson",
            "1515 Main St.",
            "https://www.facebook.com/mtyson"
          )
        )
        _ <- svc.getByName("Mike", "Tyson").andThen {
          case Success(mutant) =>
            println(s"Found mutant: ${mutant}")
        }
      } yield (),
      30.seconds
    )

    db.shutdown()
  }
}
