#!/bin/bash
set -x

export HOSTIP=$HOSTNAME
export SPARK_LOCAL_IP=$HOSTIP

# Use JAVA_HOME if set, otherwise the JDK of the `java` on your PATH.
# Spark 3.5 needs Java 8, 11 or 17.
export JAVA_HOME=${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}
export PATH=$JAVA_HOME/bin:$PATH

cd spark3/sbin 

#./stop-worker.sh spark://$HOSTIP:7077 -c 8 -m 32G
./stop-worker.sh spark://$HOSTIP:7077 -c 2 -m 2G

./stop-history-server.sh

./stop-master.sh -h $HOSTIP
