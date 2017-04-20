import Common._
import com.datastax.spark.connector._
import org.apache.log4j.{Level, Logger}
import org.apache.spark.{SparkConf, SparkContext}

import scala.collection.immutable.Nil

object Loader extends App {

  val sc = new SparkContext(new SparkConf())
  Logger.getRootLogger.setLevel(Level.ERROR)

  private val path = "/tmp/2008.csv"
  private val data = scala.io.Source.fromFile(path).getLines.drop(1)
  private var work = true

  implicit class RitaLoaderHelper(val s: String) {
    def toRitaInt = try {
      s.toInt
    } catch {
      case _: Exception => 0
    }

    def toRitaBoolean =
      s.toRitaInt == 1
  }

  while (work) {
    data.take(1000).toList match {
      case Nil => work = false
      case xs: List[String] =>
        val rita = xs.map(line => {
          val cols = line.split(",")
            Some(Rita(cols(0).toInt, cols(1).toInt, cols(2).toInt,
              cols(16), cols(17), cols(8), cols(21).toRitaBoolean, cols(10),
              cols(14).toRitaInt, cols(15).toRitaInt, cols(18).toInt, cols(9).toInt))
        })
        sc.parallelize(rita).filter(_.isDefined).map(_.get).saveToCassandra(keyspace, tableName, someColumns)
    }
  }

}
