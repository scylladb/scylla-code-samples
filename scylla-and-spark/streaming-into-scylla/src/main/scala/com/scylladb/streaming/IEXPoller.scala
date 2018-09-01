package com.scylladb.streaming

import akka.http.scaladsl._
import akka.http.scaladsl.model._
import akka.http.scaladsl.unmarshalling._
import akka.stream.{KillSwitches, Materializer}
import akka.stream.scaladsl._
import akka.util.ByteString
import cats.implicits._
import de.heikoseeberger.akkahttpcirce.ErrorAccumulatingCirceSupport
import io.circe.{Json, JsonObject}
import org.apache.kafka.clients.producer.{
  Callback,
  Producer,
  ProducerRecord,
  RecordMetadata
}
import scala.concurrent.Promise

import scala.concurrent.duration._
import scala.concurrent.ExecutionContext

object IEXPoller extends ErrorAccumulatingCirceSupport {
  def apply(
      http: HttpExt,
      producer: Producer[String, String],
      quotesTopic: String,
      symbols: List[String])(implicit ec: ExecutionContext, mat: Materializer) =
    dataSource(http, symbols)
      .to(writeToKafka(producer, quotesTopic))

  def dataSource(http: HttpExt, symbols: List[String])(
      implicit ec: ExecutionContext,
      mat: Materializer) = {
    val request = HttpRequest(uri = Uri(
      s"https://api.iextrading.com/1.0/stock/market/batch?types=quote&symbols=${symbols
        .mkString(",")}"))

    RestartSource
      .onFailuresWithBackoff(1.second, 5.seconds, 0.2) { () =>
        Source
          .unfoldAsync(()) { _ =>
            http
              .singleRequest(request)
              .flatMap(resp => Unmarshal(resp).to[JsonObject])
              .map(resp => Some(((), resp)))
          }
      }
      .throttle(1, 1.second)
      .mapConcat { data =>
        data.values.toList.map(extractFields).flatMap {
          case Right(d) => List(d)
          case Left(e)  => println(e); List()
        }
      }
      .viaMat(KillSwitches.single)(Keep.right)
  }

  def extractFields(data: Json) =
    (data.hcursor.downField("quote").get[String]("symbol"),
     data.hcursor.downField("quote").get[Long]("latestUpdate"))
      .mapN((symbol, timestamp) => (symbol, timestamp, data))

  def writeToKafka(producer: Producer[String, String], topic: String)(
      implicit ec: ExecutionContext) =
    Flow[(String, Long, Json)]
      .map {
        case (symbol, timestamp, data) =>
          new ProducerRecord(topic, null, timestamp, symbol, data.noSpaces)
      }
      .via(
        RestartFlow.onFailuresWithBackoff(1.second, 5.seconds, 0.2, 20) { () =>
          Flow[ProducerRecord[String, String]]
            .mapAsync(1000) { record =>
              val p = Promise[Unit]()

              producer.send(record, new Callback {
                def onCompletion(rec: RecordMetadata, err: Exception) =
                  if (err ne null) p.failure(err)
                  else p.success(())
              })

              p.future
            }
        }
      )
      .to(Sink.ignore)
}
