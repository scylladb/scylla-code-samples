#!/bin/bash

set -x

# Use JAVA_HOME if set, otherwise the JDK of the `java` on your PATH.
# Spark 3.5 needs Java 8, 11 or 17.
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark3/bin/spark-submit --class com.scylladb.LetterInNameCountEnrich \
  --master spark://$HOSTNAME:7077 \
  --conf spark.eventLog.enabled=true \
  target/scala-2.12/spark3-scylla4-example-assembly-0.1.jar



