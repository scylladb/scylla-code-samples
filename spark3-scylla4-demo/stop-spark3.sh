#!/bin/bash
set -x

export HOSTIP=$HOSTNAME
export SPARK_LOCAL_IP=$HOSTIP

export JAVA_HOME=/usr/lib/jvm/java-11
export PATH=$JAVA_HOME/bin:$PATH

cd spark3/sbin 

#./stop-worker.sh spark://$HOSTIP:7077 -c 8 -m 32G
./stop-worker.sh spark://$HOSTIP:7077 -c 2 -m 2G

./stop-history-server.sh

./stop-master.sh -h $HOSTIP
