#!/bin/bash
function usage {
        echo "$0 [fib number] [listener count]"
        exit 1
}

if [ $# != 2 ] ; then
        usage
        exit 1;
fi

fib_num=$1
listener_count=$2

first_worker_core_id=$((1 + $listener_count))

chmod 400 ./id_rsa

remote_ip="128.110.218.246"

#cores_list=(1 2 4 6 8 10 12 14 16 18 20 24 28 32 36 40 44 48 52 56 60 64 68 70)
#cores_list=(1 2 4 6 8 10 12 14 16 18 20 22 24)
cores_list=(9)
ulimit -n 655350


#path="/my_mount/sledge-serverless-framework/runtime/tests"
path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#cores_list[@]};i++ )) do
        server_log="server-"${cores_list[i]}"-$fib_num.log"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start.sh ${cores_list[i]} $listener_count $first_worker_core_id > $server_log 2>&1 &"
        echo "sledge start with worker core ${cores_list[i]}"
        pushd ../ 
	#scripts/do.sh 1 0 > client.txt
	scripts/do.sh 1 0 
	popd
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
	sleep 10 
done
folder_name="$fib_num""_$listener_count"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"

