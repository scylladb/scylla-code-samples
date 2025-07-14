package com.scylla.mms

import com.outworkers.phantom.dsl._
import com.scylla.mms.cql.MutantsDatabase
import com.scylla.mms.service.MutantsService

import scala.concurrent.Await
import scala.concurrent.duration._

object App {
  def main(args: Array[String]): Unit = {
    val connection: CassandraConnection = ContactPoints(Seq("localhost"))
      .keySpace("catalog")
    val db = new MutantsDatabase(connection)
    val svc = new MutantsService(db)

    println("Successfully connected to ScyllaDB database!")
    
    db.shutdown()
  }
} 