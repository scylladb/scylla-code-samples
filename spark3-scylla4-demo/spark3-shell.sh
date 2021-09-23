#!/bin/bash

set -x

export JAVA_HOME=/usr/lib/jvm/java-11/
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark3/bin/spark-shell --packages com.datastax.spark:spark-cassandra-connector_2.12:3.1.0 \
--conf spark.cassandra.connection.host=127.0.0.1 \
--conf spark.cassandra.connection.port=9044 \
--conf spark.sql.extensions=com.datastax.spark.connector.CassandraSparkExtensions
#  --master spark://tublat:7077 \
