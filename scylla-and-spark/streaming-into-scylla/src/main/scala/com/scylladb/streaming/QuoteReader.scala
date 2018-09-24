package com.scylladb.streaming

import com.datastax.spark.connector._
import org.apache.spark.sql.SaveMode
import org.apache.spark.sql.streaming.OutputMode
import org.apache.spark.sql.types._
import org.apache.spark.sql.{SQLContext, SparkSession}
import org.apache.spark.sql.execution.streaming.Sink
import org.apache.spark.sql.sources.StreamSinkProvider
import org.apache.spark.sql.{functions => f, DataFrame}
import org.apache.spark.sql.cassandra._

object QuoteReader {
  val schema = StructType(
    List(
      StructField(
        "quote",
        StructType(
          List(
            StructField("latestPrice", DoubleType),
            StructField("previousClose", DoubleType),
            StructField("latestVolume", LongType)
          )
        )
      )
    ))

  def apply(quotesTopic: String)(implicit spark: SparkSession) = {
    import spark.implicits._

    spark.readStream
      .format("kafka")
      .option("kafka.bootstrap.servers", "kafka:9092")
      .option("subscribe", quotesTopic)
      .load()
      .selectExpr("CAST(key AS STRING) AS symbol",
                  "CAST(value AS STRING) AS data",
                  "timestamp")
      .select($"symbol", $"timestamp", f.from_json($"data", schema).as("data"))
      .select(
        $"symbol",
        $"timestamp",
        f.col("timestamp").cast(DateType).cast(TimestampType).as("day"),
        $"data.quote.latestPrice".as("latest_price"),
        $"data.quote.previousClose".as("previous_close"),
        $"data.quote.latestVolume".as("latest_volume")
      )
      .writeStream
      .format("com.scylladb.streaming.ScyllaSinkProvider")
      .outputMode(OutputMode.Append)
      .options(
        Map(
          "cluster" -> "scylla",
          "keyspace" -> "quotes",
          "table" -> "quotes",
          "checkpointLocation" -> "/tmp/checkpoints"
        )
      )
      .start()
  }
}

class ScyllaSinkProvider extends StreamSinkProvider {
  override def createSink(sqlContext: SQLContext,
                          parameters: Map[String, String],
                          partitionColumns: Seq[String],
                          outputMode: OutputMode): ScyllaSink =
    new ScyllaSink(parameters)
}

class ScyllaSink(parameters: Map[String, String]) extends Sink {
  override def addBatch(batchId: Long, data: DataFrame): Unit =
    data.write
      .cassandraFormat(parameters("table"),
                       parameters("keyspace"),
                       parameters("cluster"))
      .mode(SaveMode.Append)
      .save()
}
