#!/bin/bash
function usage {
        echo "$0 [repeat count]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.219.0"

repeat_count=$1

sudo rm -rf ../sledge.log

path="/my_mount/sledge-serverless-framework/runtime/tests"
for(( i=0;i<$repeat_count;i++ )) do
    echo "i is $i"
    echo "start server..."
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start.sh 1 1 5 > 1.txt 2>&1 &"
    sleep 2 
    echo "start client..."
    pushd ../
    sudo scripts/do.sh 1 0 client.log >> sledge.log
    return_value=$?
    if [ "$return_value" -eq 1 ]; then
        i=$((i - 1))
        echo "failure, continue with i=$i"
        popd
        continue
    fi
    popd
 
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
done
