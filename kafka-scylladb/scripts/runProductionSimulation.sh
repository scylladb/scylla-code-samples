#!/bin/bash

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -c|--config)
    CONFIG="$2"
    shift # past argument
    ;;
    -d|--data)
    DATA="$2"
    shift # past argument
    ;;
    *)
    ;;

esac
shift # past argument or value
done

: "${CONFIG?Need to set kafka config. Use -c | --config}"
: "${DATA?Need to set data file. Use -d | --data}"

java -cp scylladb-kafka-1.0-SNAPSHOT-jar-with-dependencies.jar com.scylladb.sim.ProductionSimulator $CONFIG $DATA