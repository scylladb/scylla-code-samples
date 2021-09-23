package com.scylladb

import com.datastax.spark.connector._
import org.apache.spark.sql.cassandra._
import org.apache.spark.sql.{Row, SparkSession}

object LetterInNameCountEnrich {

  def main(args: Array[String]): Unit = {

    implicit val spark = SparkSession
      .builder()
      .appName("LetterInNameCountEnrich")
      .config("spark.task.maxFailures", "4")
      .config("spark.stage.maxConsecutiveAttempts", "6")
      .withExtensions(new CassandraSparkExtensions)
      .getOrCreate

    val scyllaHost = "127.0.0.1"
    val scyllaPort = "9044"

    val scyllaKeyspace = "myownkeyspace" // cassandra doesn't honor case sensitivity by default
    val scyllaTable = "sparsetable"

    spark.conf.set(s"spark.cassandra.connection.host", scyllaHost)
    spark.conf.set(s"spark.cassandra.connection.port", scyllaPort) //for some unknown reason below catalog doesn't accept a port

    spark.conf.set(s"spark.sql.catalog.localScylla", "com.datastax.spark.connector.datasource.CassandraCatalog")
    spark.conf.set(s"spark.sql.catalog.localScylla.spark.cassandra.connection.host", scyllaHost)
    spark.conf.set(s"spark.sql.catalog.localScylla.spark.cassandra.connection.port", scyllaPort) //is this really used?

    val dataset = spark.read.cassandraFormat.table(s"localScylla.$scyllaKeyspace.$scyllaTable")

    val accum = spark.sparkContext.longAccumulator("Changed Row Count")

    val missingFieldName = "lettersinname" //what field we need to fill in/enrich

    val fenriched = dataset.filter(row => row.isNullAt(row.fieldIndex(missingFieldName)))
//    val fenriched = dataset; //use this to overwrite rows with values

    val enriched = fenriched.map(
      row => {
        var frow=row.copy()
        val index = row.fieldIndex(missingFieldName)
        val name_index = row.fieldIndex("name") //count the missing field from these two fields
        val lname_index = row.fieldIndex("lname")
        val letterscount = row.getString(name_index).length + row.getString(lname_index).length
        //only update if no previous value (not needed, above filter takes care and is more effective)
//        if (row.isNullAt(index)) {
          frow = Row.fromSeq(frow.toSeq.updated(index, letterscount))
//        }
        accum.add(1)
        frow
      }
    )(fenriched.encoder)

    enriched.write.cassandraFormat(scyllaTable,scyllaKeyspace,"localScylla")
      .mode("append").save()
    println("Accumulator: \""+accum.name.getOrElse("NoName")+"\" is set to: "+accum.value)

  }


}
