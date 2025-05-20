# When use real world app to test, need to append "--initial-memory=655360" to
# WASMLDFLAGS of the Makefile in the function code under wasm_apps. This guarantees
# all moduels have the same initial memory size.

#server starts 6 workers and client starts 12 threads

#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU, EDF_INTERRUPT, DARC, TO_GLOBAL_QUEUE, RR, JSQ, LLD] [client threads count]"
        exit 1
}

if [ $# != 2 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.218.253"

echo "openloop_vision" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

dispatcher_policy=$1
json_file="vision_apps_dispatcher.json"

if [ "$dispatcher_policy" == "DARC" ]; then
    #more shorters
    throughput_percentage=(10 20 30 40 50 60 70 72 74 75 76 77 78 79 80 82 83 84 85 86 87 88 89 90)
    #same 
    #throughput_percentage=(10 20 30 40 50 60 65 70 72 74 76 78 80 82 84 86 87 88 89 90 91 92)
    #more longers
    #throughput_percentage=(10 20 30 40 50 60 65 70 71 72 73 74 75 76 77 78)
    #more longers 2
    #throughput_percentage=(10 20 30 40 50 60 65 70 75 80 82 84 85 86 87 88 89 90 91)
elif [ "$dispatcher_policy" == "EDF_INTERRUPT" ]; then
    #throughput_percentage=(100)
    #more shorters
    #throughput_percentage=(10 20 30 40 50 60 65 70 75 79 80 84 86 88 90 94 95 96 97 98 99 100 101)
    #same
    throughput_percentage=(75 79 80 82 84 86 88 94 96)
    #more longers
    #throughput_percentage=(10 20 30 40 50 60 65 70 75 79 80 82 84 86 88 90 92 94 95 96 97 98 99 100)
elif [ "$dispatcher_policy" == "SHINJUKU" ]; then
    #more shorters
    throughput_percentage=(10 20 30 40 50 60 65 70 72 73 74 75 76 77 78 79)
    #same 
    #throughput_percentage=(10 20 30 40 50 60 65 70 75 80 82 84 86 87 88 89 90 91 92 93)
    #more longers
    #throughput_percentage=(10 20 30 40 50 60 65 70 75 80 82 84 86 88 90 92 94 95 96 97)
elif [ "$dispatcher_policy" == "RR" ]; then
    #throughput_percentage=(100)
    #same shorters
    throughput_percentage=(75 79 80 84 86 88 90 94 95 96)
elif [ "$dispatcher_policy" == "JSQ" ]; then
    #throughput_percentage=(100)
    #same shorters
    throughput_percentage=(75 79 80 84 86 88 90 94 95 96)
elif [ "$dispatcher_policy" == "LLD" ]; then
    #throughput_percentage=(100)
    #same shorters
    throughput_percentage=(75 79 80 84 86 88 90 94 95 96)
fi

disable_busy_loop="true"
disable_autoscaling="true"
threads_count=$2
group_size=$(($threads_count / 2))

flag="vision"

base_throughput1=6600
base_throughput2=1650

#for more longer requests
#base_throughput1=285
#base_throughput2=285
#base_throughput3=285
#base_throughput4=285
#base_throughput5=285
#base_throughput6=2850

throughput_percentage=(100)

#8 workers
path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/clean_sledge/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"

req_type="--req_type "
for i in {1..2}; do
    for j in $(seq $group_size); do
        req_type+="$i,"
    done
done

req_type=${req_type%,}

echo $req_type

sed -i -E 's#--inputs[[:space:]]+[^-]+#--inputs ./frog5_12_cropped.bmp, ./frog5_12_cropped.bmp#' /my_mount/eRPC/apps/openloop_vision/config
sed -i "s/^--req_type.*/$req_type/" /my_mount/eRPC/apps/openloop_vision/config
for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        throughput1=$(echo "(${throughput_percentage[i]} * $base_throughput1) / 100" | bc)
        throughput2=$(echo "(${throughput_percentage[i]} * $base_throughput2) / 100" | bc)

        rps1=$(echo "($throughput1) / $group_size" | bc)
        rps2=$(echo "($throughput2) / $group_size" | bc)

	echo $rps1 $rps2 
	replacement_rps="--rps "
        for rps in $rps1 $rps2; do
    	    for j in $(seq $group_size); do
                replacement_rps+="$rps,"
            done
        done
	replacement_rps=${replacement_rps%,}
	echo $replacement_rps
	./set_rps.sh /my_mount/eRPC/apps/openloop_vision/config "$replacement_rps" 	
	total_throughput=$(($throughput1 + $throughput2))
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
        echo $client_log
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
	echo "start $dispatcher_policy ${throughput_percentage[i]} testing..."
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "likwid-powermeter sudo $path/start_test.sh $threads_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling > $cpu_log 2>&1 &"
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 14 1 3 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling false $json_file > $cpu_log 2>&1 &"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/compare_dispatchers.sh 6 1 3 $dispatcher_policy $server_log $disable_busy_loop $disable_autoscaling true $json_file > $cpu_log 2>&1 &"
	#echo "start cpu monitoring"
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/start_monitor.sh $cpu_log > /dev/null 2>&1 &"
	sleep 10
        echo "start client..."
	pushd ../
        scripts/do.sh 1 0 $client_log
	return_value=$?
	#if [ "$return_value" -eq 1 ]; then
	#	i=$((i - 1))
	#	echo "failure, continue with i=$i"
	#	popd
	#	continue
	#fi
        popd
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "$path/stop_monitor.sh"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
        sleep 10
done
#folder_name=$dispatcher_policy"-$flag"
folder_name=$dispatcher_policy
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
mkdir $folder_name
mv ../client-*.log $folder_name
