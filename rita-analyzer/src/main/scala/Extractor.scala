import java.lang.System.nanoTime

import Common._
import com.datastax.spark.connector._
import org.apache.log4j.{Level, Logger}
import org.apache.spark.storage.StorageLevel
import org.apache.spark.{SparkConf, SparkContext}

object Extractor extends App {

  def profile[R](code: => R, t: Long = nanoTime): (R, Long) = (code, nanoTime - t)

  val sc = new SparkContext(new SparkConf())
  Logger.getRootLogger.setLevel(Level.ERROR)

  val rdd = sc
    .cassandraTable[Rita](keyspace, tableName)
    .select(someColumns.columns: _*)
    .persist(StorageLevel.MEMORY_AND_DISK_SER)

  val (arrResult, arrTime) = profile {
    rdd
      .filter(_.arrdelay > 0)
      .groupBy(p => p.dest)
      .map({ case (dest, xs) =>
        DestDelay(
          dest = dest,
          delay = xs.map(x => x.arrdelay).sum / xs.size, // average delay
          carrier = xs.groupBy(_.carrier).map { gc => // group by carrier
            NameDelay(gc._1, gc._2.map(_.arrdelay).sum / gc._2.size)
          }.toList.sortWith(_.delay > _.delay).take(subGrItemsCount), // sort carrier's list by average delay DESC, take top 3
          origin = xs.groupBy(_.origin).map { gc => // group by origin
            NameDelay(gc._1, gc._2.map(_.arrdelay).sum / gc._2.size)
          }.toList.sortWith(_.delay > _.delay).take(subGrItemsCount) // sort origin's list by average delay DESC, take top 3
        )
      })
      .sortBy(_.delay, ascending = false)
      .take(grItemsCount)
  }

  println(s"Top $grItemsCount destinations with highest average arrival delay")
  arrResult.foreach { row =>
    println(s"Dest: ${row.dest}, arrival average delay: ${row.delay}")
    println(s"... Top $subGrItemsCount carriers with highest arrival average delay:")
    row.carrier.foreach(c => println(s"...... carrier: ${c.name}, arrival average delay: ${c.delay}"))
    println(s"... Top $subGrItemsCount origins with highest arrival average delay:")
    row.origin.foreach(c => println(s"...... from origin: ${c.name}, arrival average delay: ${c.delay}"))
  }


  val (depResult, depTime) = profile {
    rdd
      .filter(_.depdelay > 0)
      .groupBy(p => p.origin)
      .map({ case (origin, xs) =>
        ArrivalDelay(
          origin = origin,
          delay = xs.map(x => x.depdelay).sum / xs.size, // average delay
          carrier = xs.groupBy(_.carrier).map { gc => // group by carrier
            NameDelay(gc._1, gc._2.map(_.depdelay).sum / gc._2.size)
          }.toList.sortWith(_.delay > _.delay).take(subGrItemsCount), // sort carrier's list by average delay DESC, take top 3
          dest = xs.groupBy(_.dest).map { gc => // group by dest
            NameDelay(gc._1, gc._2.map(_.depdelay).sum / gc._2.size)
          }.toList.sortWith(_.delay > _.delay).take(subGrItemsCount) // sort dest's list by average delay DESC, take top 3
        )
      })
      .sortBy(_.delay, ascending = false)
      .take(grItemsCount)
  }

  println(s"Top $grItemsCount origins with highest average departure delay")
  depResult.foreach { row =>
    println(s"Origin: ${row.origin}, departure average delay: ${row.delay}")
    println(s"... Top $subGrItemsCount carriers with highest departure average delay:")
    row.carrier.foreach(c => println(s"...... carrier: ${c.name}, departure average delay: ${c.delay}"))
    println(s"... Top $subGrItemsCount destinations with highest departure average delay:")
    row.dest.foreach(c => println(s"...... from destination: ${c.name}, departure average delay: ${c.delay}"))
  }


  val (carrierResult, carrierTime) = profile {
    rdd
      .filter(row => row.depdelay > 0 && row.arrdelay > 0)
      .map(x => (x.carrier, (x.depdelay, x.arrdelay, 1)))
      .reduceByKey({ case (a, b) => (a._1 + b._1, a._2 + b._2, a._3 + b._3) })
      .map({ case (carrier, tuple) => CarrierResult(carrier, tuple._1 / tuple._3, tuple._2 / tuple._3) })
      .sortBy(_.departureDelay, ascending = false)
      .take(grItemsCount)
  }

  println(s"Top $grItemsCount carriers with highest average departure and arrival delay")
  carrierResult.foreach { row =>
    println(s"Carrier: ${row.carrier}, departure average delay: ${row.departureDelay}, arrival average delay: ${row.arrivalDelay}")
  }


  val (carrierCancelResult, carrierCancelTime) = profile {
    rdd
      .filter(row => row.cancelled)
      .map(rita => (rita.carrier, 1))
      .countByKey()
      .map({ case (carrier, cancellations) => CarrierCancelResult(carrier, cancellations) })
      .toList.sortWith(_.cancellations > _.cancellations)
      .take(grItemsCount)
  }

  println(s"Top $grItemsCount carriers with highest flight cancellation")
  carrierCancelResult.foreach { row =>
    println(s"Carrier: ${row.carrier}, flight cancellation count: ${row.cancellations}")
  }


  val formatter = java.text.NumberFormat.getIntegerInstance
  println(">>> >>> >>>")
  println("Total time for arrival delay calculation: " + formatter.format(arrTime))
  println("Total time for departure delay calculation: " + formatter.format(depTime))
  println("Total time for carriers' delay calculation: " + formatter.format(carrierTime))
  println("Total time for carriers' cancellation calculation: " + formatter.format(carrierCancelTime))

}
