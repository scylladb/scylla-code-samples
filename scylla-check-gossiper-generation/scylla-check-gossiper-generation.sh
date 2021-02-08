#!/bin/bash
#
# This script checks the node's gossiper generation and produces an alert if it is older 
# than 1 year.
# !
# !scylla-check-gossiper-generation.sh [-h] [-n <nodetool command, by default 'nodetool'>]
# !

usage() {
    cat $0 | grep "^# !" | cut -d"!" -f2-
}

NODETOOL_CMD="nodetool"

# set -x

while getopts ':hled:n:' option; do
  case "$option" in
    h) usage
       exit 0
       ;;
    n) NODETOOL_CMD=$OPTARG
       ;;
   \?) printf "illegal option: -%s\n" "$OPTARG" >&2
       usage
       exit 1
       ;;
  esac
done

# Check the nodetool command
if ! $NODETOOL_CMD status &> /dev/null; then
    echo "'$NODETOOL_CMD' is not a valid nodetool command. Please, provide a valid one using -n switch."
    usage
    exit 1
fi

NOW=`date +%s`
YEAR=31536000 #seconds = 365 * 24 * 60 * 60

#Get gossip generation for all nodes
$NODETOOL_CMD gossipinfo | grep -B1 'generation:' | while read line
do
    IP="$line"
    read line
    GEN=`echo $line | cut -d":" -f2`
    if [[ ! "$GEN" =~ ^[1-9]+[0-9]*$ ]]; then
        printf "Faulty output from nodetool for $IP, please try again or contact Scylla support"
        exit 1
    fi

    DIF=$(( $NOW - $GEN ))

    if [[ $DIF -gt $YEAR ]]; then
        printf "Gossiper generation for $IP is older than 1 year, please refrain from restarting Scylla service or node reboot.\nPlease contact Scylla support for next steps, prior to upgrade.\n"
    else
        printf "Gossiper generation for $IP is below 1 year, it should be safe to upgrade.\n"
    fi

    # Skip the group separator
    read line
done

