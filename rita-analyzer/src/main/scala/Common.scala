import com.datastax.spark.connector.SomeColumns

object Common {

  val keyspace = "spark_scylla"
  val tableName = "rita"
  val someColumns = SomeColumns("year", "month", "day",
    "origin", "dest", "carrier", "cancelled", "tail",
    "arrdelay", "depdelay", "distance", "flight")

  case class Rita(year: Int, month: Int, day: Int,
                  origin: String, dest: String, carrier: String, cancelled: Boolean, tail: String,
                  arrdelay: Int, depdelay: Int, distance: Int, flight: Int)

  case class NameDelay(name: String, delay: Int)

  case class DestDelay(dest: String, delay: Int, carrier: List[NameDelay], origin: List[NameDelay])

  case class ArrivalDelay(origin: String, delay: Int, carrier: List[NameDelay], dest: List[NameDelay])

  case class CarrierResult(carrier: String, departureDelay: Int, arrivalDelay: Int)

  case class CarrierCancelResult(carrier: String, cancellations: Long)

  val grItemsCount = 3
  val subGrItemsCount = 3
}
