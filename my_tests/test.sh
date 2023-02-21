#!/bin/bash
function usage {
        echo "$0 [concurrency] [fib number]"
        exit 1
}

if [ $# != 2 ] ; then
        usage
        exit 1;
fi

concurrency=$1
fib_num=$2


chmod 400 ./id_rsa
#test single c40


#cores_list=(1 2 4 6 8 10 12 14 16 18 20 24 28 32 36 40 44 48 52 56 60 64 68 70)
cores_list=(1 2)
ulimit -n 655350


path="/my_mount/erpc_sledge/runtime/tests"
for(( i=0;i<${#cores_list[@]};i++ )) do
        hey_log=${cores_list[i]}"-$fib_num-$concurrency.log" #8-38-100
        server_log="server-"${cores_list[i]}"-$fib_num-$concurrency.log"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3 "sudo $path/start.sh ${cores_list[i]} > $server_log 2>&1 &"
        echo "sledge start with worker core ${cores_list[i]}"
        pushd /my_mount/eRPC/
	#scripts/do.sh 1 0 > $hey_log
	scripts/do.sh 1 0 
	popd
	#hey -disable-compression -disable-keepalive -disable-redirects -z "60"s -c "$concurrency" -m POST -d "$fib_num" "http://10.10.1.1:10030/fib" > $hey_log
        #taskset --cpu-list 80-159 hey -disable-compression -disable-keepalive -disable-redirects -z "60"s -c "$concurrency" "http://127.0.0.1:10030/fib" > $hey_log
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3  "sudo $path/kill_sledge.sh"
	sleep 5
done
folder_name="$fib_num""_c$concurrency"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@128.110.219.3  "mv *.log $path/$folder_name"

