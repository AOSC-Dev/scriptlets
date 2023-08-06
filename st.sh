#!/bin/bash

if [[ $# != 1 ]]; then 
    echo "Usage: st [NAME]"
    exit 1
fi

tmux a -t $1

if [ $? = 1 ]; then
    tmux new -s $1
fi
