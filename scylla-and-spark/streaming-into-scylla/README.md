# Spark Streaming and Scylla

This project is a sample for integrating ScyllaDB with Spark Streaming. It implements a Spark Streaming job that writes stock qutoes data from Kafka into ScyllaDB.

It contains 3 components:
- `IEXPoller` - an Akka Streams component that polls [IEX](https://iextrading.com), an exchange providing free stock data, for quotes and writes them to a Kafka topic;
- `QuoteReader` - a Spark Streaming component that consumes the above Kafka topic and updates a table in ScyllaDB with the data;
- `Routes` - an HTTP endpoint that will query the above table and summarize, for a given date, the min/max difference for each symbol from the previous closing price.

## Running the project

First, start all the infrastructure services:
```shell
docker-compose up -d
```
This will start Zookeeper, Kafka, ScyllaDB, a Spark Master and a Spark Worker.

Next, create the keyspace and table:
```shell
./create-tables.sh
```
The `quotes` keyspace and table will be created, along with a `quotes_by_day` materialized view for running the statistics endpoint.

Finally, run the service:
```shell
./run.sh
```
This will run `sbt assembly** to create the job's jar, and submit it to the Spark master.

*Note*: it's best to run this service during trading hours, otherwise the data will be mostly static.

## Querying the endpoint

You can send an HTTP GET request to `localhost:3000/stats/<year>/<month>/<day>` to retrieve the statistics for a given day. For example:

```shell
$ http localhost:3000/stats/2018/09/04
HTTP/1.1 200 OK
Content-Length: 295
Content-Type: text/plain; charset=UTF-8
Date: Tue, 04 Sep 2018 20:19:15 GMT
Server: akka-http/10.1.4

Symbol: AAPL, max difference: -0.33%, min difference: -0.32%
Symbol: TSLA, max difference: 4.21%, min difference: 4.23%
Symbol: FB, max difference: 2.6%, min difference: 2.61%
Symbol: SNAP, max difference: 2.84%, min difference: 2.94%
Symbol: AMZN, max difference: -1.35%, min difference: -1.33%
```
