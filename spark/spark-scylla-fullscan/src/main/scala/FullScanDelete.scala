package com.scylladb

import com.datastax.spark.connector._
import com.datastax.spark.connector.cql.{CassandraConnector, CassandraConnectorConf, IpBasedContactInfo, Schema}
import com.datastax.spark.connector.writer.SqlRowWriter
import org.apache.log4j.LogManager
import org.apache.spark.sql.{Row, SparkSession}
import org.apache.spark.sql.cassandra._

import java.net.InetSocketAddress
import scala.collection.immutable.Seq

// Let's do a full scan and filter based on UUID
// let's delete those rows then as part of cleanup

object FullScanDelete {

  def main(args: Array[String]): Unit = {

    val log = LogManager.getLogger("com.scylladb.FullScan")

    implicit val spark: SparkSession = SparkSession
      .builder()
      .appName("FullScanApp")
      .config("spark.task.maxFailures", "4")
      .config("spark.stage.maxConsecutiveAttempts", "6")
      .withExtensions(new CassandraSparkExtensions)
      .getOrCreate()

//    val scyllaHost = "127.0.0.1"
//    val scyllaPort = 9044

    val scyllaHost = "192.168.1.177"
    val scyllaPort = 9042

    val scyllaKeyspace = "datastore" // cassandra doesn't honor case sensitivity by default
    val scyllaTable = "data"

    spark.conf.set(s"spark.cassandra.connection.host", scyllaHost)
    spark.conf.set(s"spark.cassandra.connection.port", scyllaPort) //for some unknown reason below catalog doesn't accept a port

    spark.conf.set(s"spark.sql.catalog.localScylla", "com.datastax.spark.connector.datasource.CassandraCatalog")
    spark.conf.set(s"spark.sql.catalog.localScylla.spark.cassandra.connection.host", scyllaHost)
    spark.conf.set(s"spark.sql.catalog.localScylla.spark.cassandra.connection.port", scyllaPort) //is this really used?

    val connector = new CassandraConnector(CassandraConnectorConf (spark.sparkContext.getConf.clone()).copy(
      contactInfo = IpBasedContactInfo(
        hosts = Set(new InetSocketAddress(scyllaHost, scyllaPort))
      )
    ))

    val compareFieldName = "owner_id" //what field we need to filter on
    val filterValue = "d46cb523-4202-4212-a8e9-024d46529907" //we are just interested into this ID

    val dataset = spark.read.cassandraFormat.table(s"localScylla.$scyllaKeyspace.$scyllaTable")

    val accum = spark.sparkContext.longAccumulator("Deleted Row Count")

    val filtered_dataset = dataset.filter(row =>
      row.getString(row.fieldIndex(compareFieldName)) == filterValue
          )

    val deleteRows = filtered_dataset.map(
      row => {
        //print(row)
        accum.add(1)
        val frow = Row.fromSeq(Seq(row.get(0),row.get(1))) //TODO rewrite in dynamic way to match just PK for deletes
        frow
      }
    )(filtered_dataset.encoder)

    deleteRows.rdd.deleteFromCassandra(scyllaKeyspace,scyllaTable)(connector, SqlRowWriter.Factory)
    println("Accumulator: \""+accum.name.getOrElse("NoName")+"\" is set to: "+accum.value)

  }


}
