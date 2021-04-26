#!/bin/bash

set -e

interactive=1
if [[ "$1" == "--non-interactive" ]]; then
    interactive=0
fi

function wait() {
    if [[ ${interactive} -gt 0 ]]; then
        echo -ne "\n\n$1. Press any key to continue"
        while [ true ] ; do
            read -t 10 -n 1
            if [[ $? = 0 ]] ; then
                return
            fi
        done
        echo
    else
        echo -ne "\n\n$1."
    fi
}

function wait-for-object-creation {
    for i in {1..30}; do
        { kubectl -n "${1}" get "${2}" && break; } || sleep 1
    done
}
