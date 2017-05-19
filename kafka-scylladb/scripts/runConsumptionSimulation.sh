#!/bin/bash

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -t|--topic)
    TOPIC="$2"
    shift # past argument
    ;;
    -kc|--kafka-config)
    KCONFIG="$2"
    shift # past argument
    ;;
    -g|--group)
    GROUP="$2"
    shift # past argument
    ;;
    -n|--nconsumers)
    NCONSUMERS="$2"
    shift # past argument
    ;;
    -sc|--scylla-config)
    SCONFIG="$2"
    shift # past argument
    ;;
    *)
    ;;

esac
shift # past argument or value
done

: "${TOPIC?Need to set topic. Use -t | --topic}"
: "${KCONFIG?Need to set kafka config. Use -kc | --kafka-config}"
: "${GROUP?Need to set data file. Use -g | --group}"
: "${NCONSUMERS?Need to set data file. Use -n | --nconsumers}"
: "${SCONFIG?Need to set Scylla host. Use -sh|--scylla-config}"


java -cp scylladb-kafka-1.0-SNAPSHOT-jar-with-dependencies.jar com.scylladb.sim.ConsumptionSimulator $TOPIC $KCONFIG $GROUP $NCONSUMERS $SCONFIG