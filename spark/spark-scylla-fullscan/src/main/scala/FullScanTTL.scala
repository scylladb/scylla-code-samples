package com.scylladb

import com.datastax.oss.driver.api.core.ConsistencyLevel
import com.datastax.spark.connector._
import com.datastax.spark.connector.cql.{CassandraConnector, CassandraConnectorConf, IpBasedContactInfo, NoAuthConf, PasswordAuthConf, Schema}
import org.apache.log4j.LogManager
import org.apache.spark.sql.cassandra._
import org.apache.spark.sql.{Column, Row, SparkSession}
import com.datastax.spark.connector._
import com.datastax.spark.connector.rdd.CassandraTableScanRDD
import com.datastax.spark.connector.writer.{SqlRowWriter, TTLOption, WriteConf}
import org.apache.spark.rdd.RDD

import java.net.InetSocketAddress

// Let's do a full scan and filter based on UUID
// for those rows let's do a TTL update

object FullScanTTL {

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

    val tableDef =
      connector.withSessionDo(Schema.tableFromCassandra(_, scyllaKeyspace, scyllaTable))
    log.info("TableDef retrieved for source:")
    log.info(tableDef)

        val columnRefs =
          tableDef.partitionKey.map(_.ref) ++
            tableDef.clusteringColumns.map(_.ref) ++
            tableDef.regularColumns//.map(_.ref)
              .flatMap { column =>
              val colName = column.columnName
              List(
                column.ref,
                colName.ttl as s"${colName}_ttl",
                colName.writeTime as s"${colName}_writetime"
              )
            }
    log.info("ColumnRefs generated for selection:")
    log.info(columnRefs.mkString("\n"))

    val compareFieldName = "owner_id" //what field we need to filter on
    val compareFieldNameTTL = "data_ttl"
    val compareFieldNameTTLCQL = "ttl(data) as "+compareFieldNameTTL

    //below is not needed if we don't convert to text
    val cols = columnRefs.map (
      e => e.cqlValueName
    )
    val first=cols.head
    var restc = cols.slice(2, cols.length)
//    println(first)
//    println(restc)
    restc = restc ++  Seq(compareFieldNameTTLCQL)

//    log.info("list of selectors:")
//    log.info(restc.mkString("\n"))

    //val colsmanualbase = Seq("id","group_id")
    val colsmanualbase =  tableDef.partitionKey.map(_.ref) ++
      Seq(tableDef.regularColumns.map(_.ref).find(p => p.columnName=="data").get)

    val ttlstabledef = tableDef.regularColumns.flatMap { column =>
      val colName = column.columnName
      List(
        column.ref,
        colName.ttl as s"${colName}_ttl",
        colName.writeTime as s"${colName}_writetime"
      )
    }

    val colsmanual = colsmanualbase ++
      Seq(tableDef.regularColumns.map(_.ref).find(p => p.columnName=="owner_id").get) ++
      Seq(ttlstabledef.find(p => p.cqlValueName=="ttl(data)").get)


    val dataset = spark.sparkContext
      .cassandraTable[CassandraSQLRow](
        scyllaKeyspace,
        scyllaTable)
      .withConnector(connector)
      //.read.cassandraFormat.table(s"localScylla.$scyllaKeyspace.$scyllaTable").rdd.asInstanceOf[CassandraTableScanRDD[CassandraSQLRow]]
      .select(colsmanual: _*)
// TODO above is hardcoded schema, so all below instead of recalling index has to use hardcoded position based on above, fix to schema

      //.select(first,cols:_*)

//      .select(first,restc:_*)
//      .cassandraTable[CassandraSQLRow]

    val accum = spark.sparkContext.longAccumulator("Changed Row Count")

    val filterValue = "d46cb523-4202-4212-a8e9-024d46529907" //we are just interested into this ID

    val filtered_dataset = dataset.filter(row =>
      row.getString(3) == filterValue //row.fieldIndex(compareFieldName)  // IF we have our subset of data found
        && row.get(4) == null // IF TTL is null (so old data before alter TTL was done, we can even check if TTL is too low, etc. )
          )

    //TODO fetch ALL rows which ttl you want to update in second step to save network costs

    val updatedTTL = filtered_dataset.map(
      row => {
//          print(row)
//          val ttl = row.getLong(4)
//        val ttl = row.getLong(compareFieldNameTTL)
//        print (ttl);
//        println(row.get(row.fieldIndex(compareFieldNameTTL)))
        accum.add(1)
        val frow = Row.fromSeq(Seq(row.get(0),row.get(1),row.get(2))) //TODO rewrite to match schema / colsmanualbase
        frow
      }
    )
    //(filtered_dataset.encoder)

    val tempWriteConf = WriteConf
      .fromSparkConf(spark.sparkContext.getConf)
      .copy(consistencyLevel = ConsistencyLevel.LOCAL_QUORUM)

    val writeConf =
        tempWriteConf.copy(ttl = TTLOption.constant(200000));

    val columnSelector = SomeColumns(colsmanualbase: _*) // this has to match original rdd with selected columns !!!

//    updatedTTL.collect()

    updatedTTL.asInstanceOf[RDD[Row]]
      .saveToCassandra(
        scyllaKeyspace,
        scyllaTable,
        columnSelector,
        writeConf
    ) (connector, SqlRowWriter.Factory)

    println("Accumulator: \""+accum.name.getOrElse("NoName")+"\" is set to: "+accum.value)

  }


}
