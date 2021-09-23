#!/bin/bash

set -x

export JAVA_HOME=/usr/lib/jvm/java-1.8.0/
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark/bin/spark-shell --packages com.datastax.spark:spark-cassandra-connector_2.11:2.4.3 \
--conf spark.cassandra.connection.host=127.0.0.1 \
--conf spark.cassandra.connection.port=9044
#  --master spark://tublat:7077 \
