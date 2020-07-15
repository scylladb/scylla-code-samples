#!/bin/bash

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
