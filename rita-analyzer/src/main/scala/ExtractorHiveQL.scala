import Common._
import com.datastax.spark.connector._
import org.apache.spark.SparkConf
import org.apache.spark.sql.{DataFrame, SparkSession}


object ExtractorHiveQL extends App {

  val spark = SparkSession
    .builder()
    .config(new SparkConf())
    .enableHiveSupport()
    .getOrCreate()

  val rdd = spark.sparkContext.cassandraTable[Rita](keyspace, tableName)

  import spark.implicits._

  val df: DataFrame = rdd.select(someColumns.columns: _*).toDF()
  df.createOrReplaceTempView("df_rita")

  // PARTITION BY with partitioning, ORDER BY, and window specification
  spark.sql("SELECT origin, dest, SUM(distance) OVER (PARTITION BY origin, dest ORDER BY origin, dest ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) FROM df_rita")
    .collect()
    .foreach(println)

}
