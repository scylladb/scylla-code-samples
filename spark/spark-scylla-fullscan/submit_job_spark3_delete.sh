#!/bin/bash

set -x

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64/
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark3/bin/spark-submit --class com.scylladb.FullScanDelete \
  --master spark://$HOSTNAME:7077 \
  --conf spark.eventLog.enabled=true \
  target/scala-2.13/spark-scylla-fullscan-assembly-0.1.jar



