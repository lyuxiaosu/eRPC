#!/bin/bash
function usage {
        echo "$0"
        exit 1
}

if [ $# != 0 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.219.9"

echo "closeloop_client" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

dispatcher_policy="EDF_INTERRUPT"
disable_busy_loop="true"
disable_autoscaling="true"
disable_service_ts_simulation="true"

path="/my_mount/sledge-serverless-framework/runtime/tests"
function run_tests() {
    local worker_count=("${!1}")
    local listener_num="$2"
    local worker_core_start_idx=$((2 + $listener_num + 1))

    for(( i=0;i<${#worker_count[@]};i++ )) do  
        local worker_group_size=$((${worker_count[i]} / listener_num))
	echo "worker group size: $worker_group_size"
 
	concurrency=$((${worker_count[i]} * 2))
        #python3 ../generate_config.py $worker_group_size  0 1 0 1 1 $worker_group_size $listener_num
        #python3 ../generate_config.py ${worker_count[i]} 0 1 0 1 1 $listener_num $listener_num
        #python3 ../generate_config.py 20 0 1 0 1 1 $worker_group_size $listener_num
        python3 ../generate_config.py 10 0 1 0 1 1 60 $listener_num
        cp config ../apps/closeloop_client/
	server_log="server-${listener_num}-${worker_group_size}-${worker_count[i]}.log"
	client_log="client-${listener_num}-${worker_group_size}-${worker_count[i]}.log"
	#cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server with worker ${worker_count[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh ${worker_count[i]} $listener_num $worker_core_start_idx $dispatcher_policy $server_log $disable_busy_loop $disable_autoscaling $disable_service_ts_simulation "empty.json" > 1.txt 2>&1 &"
        sleep 5
	#echo "start cpu monitoring"
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/start_monitor.sh $cpu_log > /dev/null 2>&1 &"
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
    folder_name=$listener_num"_listener"
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
    mkdir $folder_name
    mv ../client-*.log $folder_name
}

#worker_count1=(1 3 6 9 12 15)
worker_count1=(5 10 15)
#worker_count2=(3 6 9 12 15)

run_tests "worker_count1[@]" 5
#run_tests "worker_count2[@]" 3 

