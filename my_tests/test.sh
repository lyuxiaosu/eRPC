#!/bin/bash
function usage {
        echo "$0 [concurrency] [fib number] [listener count]"
        exit 1
}

if [ $# != 3 ] ; then
        usage
        exit 1;
fi

concurrency=$1
fib_num=$2
listener_count=$3


chmod 400 ./id_rsa


#cores_list=(1 2 4 6 8 10 12 14 16 18 20 24 28 32 36 40 44 48 52 56 60 64 68 70)
cores_list=(1 2 4 6 8 10 12 14 16 18 20 22 24 26 28)
ulimit -n 655350


path="/my_mount/erpc_sledge/runtime/tests"
for(( i=0;i<${#cores_list[@]};i++ )) do
        server_log="server-"${cores_list[i]}"-$fib_num-$concurrency.log"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3 "sudo $path/start.sh ${cores_list[i]} $listener_count > $server_log 2>&1 &"
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3 "sudo $path/start.sh ${cores_list[i]} 1"
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3 "sudo $path/start.sh ${cores_list[i]} 2"
        echo "sledge start with worker core ${cores_list[i]}"
        pushd /my_mount/eRPC/
	#scripts/do.sh 1 0 > client.txt
	scripts/do.sh 1 0 
	popd
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3  "sudo $path/kill_sledge.sh"
	sleep 10 
done
folder_name="$fib_num""_c$concurrency""_$listener_count"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3  "mv *.log $path/$folder_name"

