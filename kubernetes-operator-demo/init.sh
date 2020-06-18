#!/bin/bash

interactive=1
if [[ "$1" == "--non-interactive" ]]; then
    interactive=0
fi

function wait() {
    if [ $interactive -gt 0 ]; then
        echo -ne "$1. Press any key to continue"
        while [ true ] ; do
            read -t 10 -n 1
            if [ $? = 0 ] ; then
                return
            fi
        done
    else
        echo -ne "$1."
    fi
}