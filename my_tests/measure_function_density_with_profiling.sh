#this script measure function density with openloop to compare with rFaaS 
#!/bin/bash
function usage {
        echo "$0 <server worker count> <listener_count> <pool_per_module, no_memory_pool or empty>"
        exit 1
}

if [ $# -lt 2 ] ; then
        usage
        exit 1;
fi

echo "function_density" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

rps=40000
threads=10
per_rps=$(($rps / $threads))
worker_count=$1
listener_count=$2
server_type=$3
worker_core_start_idx=$((2 + $listener_count + 1))
chmod 400 ./id_rsa
remote_ip="128.110.218.251"

#concurrency=(1 10 20 24 28 30 32 40 100 300 500 700 900 1100 1300 1500 1700 1900 2000)
#concurrency=(2000)
concurrency=(32)

#path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/pool_per_module/sledge-serverless-framework/runtime/tests"
#path="/my_mount/no_memory_pool/sledge-serverless-framework/runtime/tests"
path="/my_mount/$server_type/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#concurrency[@]};i++ )) do
	echo "i is $i"
        func_types=${concurrency[i]}
        python3 ../generate_config.py $threads 0 $per_rps 0 1 0 1 1 $func_types 1
        cp config ../apps/function_density/
	client_log="client-${concurrency[i]}.log"
	server_log="server-${concurrency[i]}.log"
        echo "start sledge server for concurrency ${concurrency[i]} testing..."
	ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "python3 $path/generate_json_with_replica_field.py ${concurrency[i]} config.json"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "mv config.json $path/"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_func_density_test.sh $worker_count $listener_count $worker_core_start_idx config.json $server_log > 1.txt 2>&1 &"
        echo "server started"
	sleep 10 
	echo "run perf..."
	perf_log="${concurrency[i]}_perf.log"
	mem_log="${concurrency[i]}_mem.log"
	ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/run_perf.sh $perf_log > /dev/null 2>&1 &"
        #echo "start cpu monitoring"
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/start_monitor.sh $cpu_log > /dev/null 2>&1 &" 
	ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/monitor_mem.sh $mem_log > /dev/null 2>&1 &" 
	echo "start client..."
        pushd ../
        scripts/do.sh 1 0 $client_log
        return_value=$?
        if [ "$return_value" -eq 1 ]; then
                i=$((i - 1))
                echo "failure, continue with i=$i"
                popd
                continue
        fi
        popd

	ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "$path/kill_perf.sh"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
        sleep 4 
done
folder_name="Sledge_$server_type"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"

mkdir $folder_name
mv ../client-*.log $folder_name
