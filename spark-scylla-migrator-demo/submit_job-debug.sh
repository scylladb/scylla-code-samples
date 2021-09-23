#!/bin/bash

set -x

. spark-env

export JAVA_HOME=/usr/lib/jvm/java-1.8.0/
export PATH=$JAVA_HOME/bin:$PATH

mkdir /tmp/savepoints

./spark/bin/spark-submit --class com.scylladb.migrator.Migrator \
  --driver-java-options -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=65005 \
  --master spark://tublat:7077 \
  --conf spark.scylla.config=config.yaml \
  --conf spark.cassandra.input.consistency.level=LOCAL_QUORUM \
  --conf spark.cassandra.output.consistency.level=LOCAL_QUORUM \
  --num-executors 1 \
  --executor-memory $MEMORY \
  --conf "spark.executor.extraJavaOptions=-agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=64000 -XX:+HeapDumpOnOutOfMemoryError" \
  --conf spark.cassandra.connection.localConnectionsPerExecutor=4 \
  scylla-migrator/target/scala-2.11/scylla-migrator-assembly-0.0.1.jar

#-XX:+HeapDumpOnOutOfMemoryError -XX:+PrintGCDetails


