#!/bin/bash
set -x

export HOSTIP=$HOSTNAME
export SPARK_LOCAL_IP=$HOSTIP

export JAVA_HOME=/usr/lib/jvm/java-11
export PATH=$JAVA_HOME/bin:$PATH

cd spark3/sbin 

./start-master.sh

/bin/mkdir /tmp/spark-events

./start-history-server.sh

#./start-worker.sh spark://$HOSTIP:7077 -c 8 -m 32G
./start-worker.sh spark://$HOSTIP:7077 -c 2 -m 2G

#./start-shuffle-service.sh
