#!/bin/bash
#
# This script checks the node's gossiper generation and produces an alert if it is older 
# than 1 year.

set -e

GEN=`nodetool gossipinfo | grep 'generation:'|awk -F':' '{ print $2 }'`
NOW=`date +%s`
DIF=$(( $NOW - $GEN ))
YEAR=31536000 #seconds = 365 * 24 * 60 * 60

if [[ $DIF -gt $YEAR ]]; then 
    printf "Gossiper generation older than 1 year, please refrain from restarting Scylla service or node reboot.\nPlease contact Scylla support for next steps, prior to upgrade.\n"
else
    printf "Gossiper generation is below 1 year, it should be safe to upgrade.\n"
fi
