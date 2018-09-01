package com.scylladb.streaming

import akka.http.scaladsl.server.Directives
import com.datastax.spark.connector._
import org.apache.spark.sql.cassandra._
import org.apache.spark.sql.{functions => f, SparkSession}

object Routes extends Directives {
  def apply(spark: SparkSession) = {
    import spark.implicits._

    val quotes = spark.read
      .cassandraFormat("quotes", "quotes", "scylla")
      .load()

    path("stats" / IntNumber / IntNumber / IntNumber) { (year, month, day) =>
      val result = quotes
        .where($"day" === f.to_timestamp(f.lit(s"${year}-${month}-${day}"),
                                         "yy-MM-dd"))
        .groupBy($"symbol")
        .agg(
          f.max("latest_price").as("max_price"),
          f.min("latest_price").as("min_price"),
          f.min("previous_close").as("previous_close")
        )
        .select(
          $"symbol",
          f.round(((f.col("previous_close") - f.col("max_price")) / f.col(
                     "previous_close")) * 100,
                   2)
            .as("max_difference"),
          f.round(((f.col("previous_close") - f.col("min_price")) / f.col(
                     "previous_close")) * 100,
                   2)
            .as("min_difference")
        )
        .collect()

      val formatted = result
        .map { row =>
          s"Symbol: ${row.get(0)}, max difference: ${row.get(1)}%, min difference: ${row.get(2)}%"
        }
        .mkString("\n")

      complete(formatted)
    }
  }
}
