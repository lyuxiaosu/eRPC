#!/bin/bash
function usage {
        echo "$0"
        exit 1
}

if [ $# != 0 ] ; then
        usage
        exit 1;
fi

client_worker_count=10
chmod 400 ./id_rsa
remote_ip="128.110.219.9"

echo "function_density" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"

function run_tests() {
    local throughput_percentage=("${!1}")
    local server_worker_count="$2"
    local listener_count="$3"
    local total_types="$4"
    local flag="${server_worker_count}_workers_${total_types}"
    local base_throughput=$((100000 * $server_worker_count))
    local worker_start_idx=$(($listener_count + 2 + 1))

    for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        per_throughput=$(echo "(${throughput_percentage[i]} * $base_throughput) / 100 / $client_worker_count" | bc)
	python3 ../generate_config.py $client_worker_count 0 $per_throughput 0 1 0 1 $listener_count $total_types 1
        cp config ../apps/function_density/

	echo ${throughput_percentage[i]} $per_throughput
        total_throughput=$(echo "($base_throughput * ${throughput_percentage[i]} / 100)" | bc)
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
        echo $client_log
        echo "start server for ${throughput_percentage[i]} testing..."
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "likwid-powermeter sudo $path/start_test.sh $worker_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling > $cpu_log 2>&1 &"
	ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "python3 $path/generate_json_with_replica_field.py $total_types config.json"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "mv config.json $path/"

	ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_func_density_test.sh $server_worker_count $listener_count $worker_start_idx config.json $server_log > 1.txt 2>&1 &"

	#echo "start cpu monitoring"
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/start_monitor.sh $cpu_log > /dev/null 2>&1 &"
	sleep 20
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
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "$path/stop_monitor.sh"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
        sleep 10
    done
    folder_name=$flag
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
    mkdir $folder_name
    mv ../client-*.log $folder_name
}

throughput_percentage1=(1 10 20 30 40 50 60 70 80 90 100 110 120 122 123 124 125)
#1 core 1 function
run_tests "throughput_percentage1[@]" 1 1 1
#1 core 10000 functions
throughput_percentage2=(1 10 20 30 32 34 36 38 40 41 42)
run_tests "throughput_percentage2[@]" 1 1 10000

#2 cores 1 function
throughput_percentage3=(1 10 20 30 40 50 60 70 80 90 100 110 120 122 123 124 125 126)
run_tests "throughput_percentage3[@]" 2 1 1

#2 cores 10000 functions
throughput_percentage4=(1 10 20 30 32 34 36 38 40 41 42)
run_tests "throughput_percentage4[@]" 2 1 10000

#6 cores 1 function
throughput_percentage5=(1 10 20 30 40 50 60 70 80 90 100 110 120 122 123 124 125)
run_tests "throughput_percentage5[@]" 6 3 1

#6 cores 10000 functions
throughput_percentage6=(1 10 20 30 32 34 36 38 40 42 43 44)
run_tests "throughput_percentage6[@]" 6 3 10000
