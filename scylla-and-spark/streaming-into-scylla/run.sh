#!/bin/bash

set -e
set -x

sbt assembly
docker-compose exec spark-master spark-submit \
    --class com.scylladb.streaming.Streaming \
    --master spark://spark-master:7077 \
    --conf spark.scylla.quotes=aapl,fb,snap,tsla,amzn \
    /jars/streaming-into-scylla-assembly-0.0.1.jar
