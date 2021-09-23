#!/bin/bash

set -x

. spark-env

export JAVA_HOME=/usr/lib/jvm/java-1.8.0/
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark/bin/spark-submit --class com.scylladb.migrator.Validator \
  --master spark://$HOSTNAME:7077 \
  --conf spark.eventLog.enabled=true \
  --conf spark.scylla.config=config.yaml \
  --conf spark.cassandra.input.consistency.level=LOCAL_QUORUM \
  --conf spark.cassandra.output.consistency.level=LOCAL_QUORUM \
  --num-executors $SPARK_WORKER_INSTANCES \
  --executor-memory $MEMORY \
  --conf spark.cassandra.connection.localConnectionsPerExecutor=4 \
  scylla-migrator/target/scala-2.11/scylla-migrator-assembly-0.0.1.jar


