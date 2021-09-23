#!/bin/bash

set -x

export JAVA_HOME=/usr/lib/jvm/java-11/
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark3/bin/spark-submit --class com.scylladb.LetterInNameCountEnrich \
  --master spark://$HOSTNAME:7077 \
  --conf spark.eventLog.enabled=true \
  target/scala-2.12/spark3-scylla4-example-assembly-0.1.jar



