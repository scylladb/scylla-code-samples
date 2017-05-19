#!/bin/bash

while [[ $# -gt 1 ]]
do
key="$1"

case $key in
    -k|--key)
    _KEY="$2"
    shift # past argument
    ;;
    -u|--user)
    USER="$2"
    shift # past argument
    ;;
    -h|--host)
    HOST="$2"
    shift # past argument
    ;;
    *)
    ;;

esac
shift # past argument or value
done

: "${_KEY?Need to set key file. Use -k | --key}"
: "${USER?Need to set user. Use -u | --user}"
: "${HOST?Need to set host. Use -h | --host}"

ssh -i $_KEY $USER@$HOST << EOF

cqlsh

create table keyspace1.s_p_prices (
    date timestamp,
    symbol varchar,
    open varchar,
    close varchar,
    low varchar,
    high varchar,
    volume varchar,
    PRIMARY KEY (date, symbol)
);

EOF