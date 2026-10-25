#!/bin/bash

set -x

# Use JAVA_HOME if set, otherwise the JDK of the `java` on your PATH.
# Spark 3.5 needs Java 8, 11 or 17.
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark3/bin/spark-shell --packages com.datastax.spark:spark-cassandra-connector_2.12:3.5.1 \
--conf spark.cassandra.connection.host=127.0.0.1 \
--conf spark.cassandra.connection.port=9044 \
--conf spark.sql.extensions=com.datastax.spark.connector.CassandraSparkExtensions
#  --master spark://tublat:7077 \
