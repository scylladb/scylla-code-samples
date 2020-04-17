#!/bin/bash
#
# This script checks the node's gossiper generation and produces an alert if it is older 
# than 1 year.

set -e

# Check for varying broadcast address and listen address settings
LISTN=`grep 'listen_address:' /etc/scylla/scylla.yaml|awk -F':' '{ print $2 }' | xargs`
BCAST=`grep 'broadcast_address:' /etc/scylla/scylla.yaml`
if [[ "$BCAST" =~ ^#.* ]]; then
    IP="$LISTN"
else
    BCAST=`grep 'broadcast_address:' /etc/scylla/scylla.yaml|awk -F':' '{ print $2 }' | xargs`
    IP="$BCAST"
fi

#Get gossip generation only for current node
GEN=`nodetool gossipinfo | grep -A1 "$IP" | grep 'generation:' | awk -F':' '{ print $2 }' | xargs`
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
