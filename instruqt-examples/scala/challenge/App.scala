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
            println("Data that we have in the catalog".center(50, "="))
            mutants.foreach(mutant => 
              println(s"${mutant.firstName} ${mutant.lastName}")
            )
        }
        _ <- addMutant(svc, "Miles", "Morales", "42 Brooklyn St", "https://www.facebook.com/miles-morales")
        _ <- checkForMutant(svc, "Miles", "Morales").andThen {
          case Success(exists) =>
            if (exists) {
              println("Congratulations! You've successfully added Miles in the mutant database and have passed the challenge!")
            } else {
              println("Miles Morales was not found in the database. Check your INSERT parameters!")
            }
        }
      } yield (),
      30.seconds
    )

    db.shutdown()
  }

  def addMutant(svc: MutantsService, firstName: String, lastName: String, address: String, pictureLocation: String) = {
    // TODO: Implement this function - replace the line below with the actual implementation
    throw new NotImplementedError("You need to implement the 'addMutant' function")
  }

  def checkForMutant(svc: MutantsService, firstName: String, lastName: String) = {
    svc.getByName(firstName, lastName).map(_.isDefined)
  }
} 