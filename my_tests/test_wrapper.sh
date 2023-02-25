#!/bin/bash

function usage {
        echo "$0 [max listener count]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

max_listener_count=$1

for ((i=1; i<=$max_listener_count; i=i+1))
do
        new_line="--num_server_threads ${i}"
        sed -i "3c ${new_line}" ../apps/server_rate/config
        ./test.sh 100 15 $i
done

