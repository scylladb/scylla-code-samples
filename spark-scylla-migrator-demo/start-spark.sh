#!/bin/bash
set -x

. spark-env

export SPARK_LOCAL_IP=$HOSTIP

export JAVA_HOME=/usr/lib/jvm/java-1.8.0/
export PATH=$JAVA_HOME/bin:$PATH

cd spark/sbin

./start-master.sh

/bin/mkdir /tmp/spark-events

./start-history-server.sh

./start-slave.sh spark://$HOSTIP:7077 $SLAVESIZE

./start-shuffle-service.sh


