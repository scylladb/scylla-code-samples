#!/bin/bash
#
# This script checks the node's gossiper generation and produces an alert if it is older 
# than 1 year.

set -e

# Check for varying broadcast address and listen address settings
LISTN=`awk -F':' '$1~/^listen_address/{ print $2}' /etc/scylla/scylla.yaml`
BCAST=`awk -F':' '$1~/^broadcast_address/{ printf $2}' /etc/scylla/scylla.yaml`
if [ $BCAST ] 
then
    IP="$LISTN"
else
    IP="$BCAST"
fi

#Get gossip generation only for current node
GEN=`nodetool gossipinfo | awk -F':' '$1~/10.88.0.2/{ getline;print $2}'`
if [[ ! "$GEN" =~ ^[1-9]+[0-9]*$ ]]; then
    printf "Faulty output from nodetool, please try again or contact Scylla support"
    exit 1
fi
NOW=`date +%s`
DIF=$(( $NOW - $GEN ))
YEAR=31536000 #seconds = 365 * 24 * 60 * 60

if [[ $DIF -gt $YEAR ]]; then 
    printf "Gossiper generation older than 1 year, please refrain from restarting Scylla service or node reboot.\nPlease contact Scylla support for next steps, prior to upgrade.\n"
else
    printf "Gossiper generation is below 1 year, it should be safe to upgrade.\n"
fi
