package com.scylladb.streaming

import akka.actor.ActorSystem
import akka.http.scaladsl.Http
import akka.stream.ActorMaterializer
import com.datastax.spark.connector._
import com.datastax.spark.connector.cql.CassandraConnectorConf
import java.util.Properties
import org.apache.kafka.clients.producer.KafkaProducer
import org.apache.kafka.common.serialization.StringSerializer
import org.apache.spark.sql.SparkSession
import org.apache.spark.sql.cassandra._

import scala.concurrent.{Await, Promise}
import scala.concurrent.duration._
import scala.util.Failure

object Streaming {
  def main(args: Array[String]): Unit = {
    implicit val system = ActorSystem("ScyllaStreaming")
    implicit val ec = system.dispatcher
    implicit val mat = ActorMaterializer()

    implicit val session = SparkSession.builder
      .appName("ScyllaStreaming")
      .getOrCreate()
      .setCassandraConf(
        "scylla",
        Map(CassandraConnectorConf.ConnectionHostParam.name -> "scylla"))

    val producer = {
      val props = new Properties
      props.put("bootstrap.servers", "kafka:9092")
      props.put("retries", "20")

      new KafkaProducer(props, new StringSerializer, new StringSerializer)
    }

    val quotesToRetrieve = session.conf
      .get("spark.scylla.quotes", "aapl,fb,snap")
      .split(",")
      .toList

    val poller =
      IEXPoller(Http(), producer, "quotes", quotesToRetrieve)
        .run()
    val quoteReader = QuoteReader("quotes")

    val bindFuture =
      Http().bindAndHandle(Routes(session), "0.0.0.0", 3000).andThen {
        case Failure(e) => println("Failed to bind: ${e}")
      }

    val shutdownSignal = Promise[Unit]()
    addShutdownHook(shutdownSignal)

    Await.result(shutdownSignal.future, Duration.Inf)

    poller.shutdown()
    producer.close()
    quoteReader.stop()
    system.terminate()
    session.stop()
  }

  def addShutdownHook(signal: Promise[Unit]): Unit =
    sys.addShutdownHook {
      signal.success(())
    }
}
