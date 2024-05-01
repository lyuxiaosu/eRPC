#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU or EDF_INTERRUPT or DARC] [disable busy loop, true or false] [disable autoscaling] [worker count]"
        exit 1
}

if [ $# != 4 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.219.0"

dispatcher_policy=$1
disable_busy_loop=$2
disable_autoscaling=$3
worker_count=$4

flag="disable-busy-loop-$disable_busy_loop-disable-autoscaling-$disable_autoscaling-$worker_count"
#base_throughput1=32344
#base_throughput2=32344
base_throughput1=16000
base_throughput2=16000

#throughput_percentage=(10 20 30 40 50 60)
#throughput_percentage=(1 5 10 15)
#for shinjuku
#throughput_percentage=(1 5 10 15 20 25 26 27 28 29 30 35 40)
throughput_percentage=(36 37 38 39)

#for EDF_INTERRUPT 
#throughput_percentage=(1 5 10 15 20 25 30 35 40 41 42 43 44 46 46.5 46.6)

path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        #per_throughput1=$(( (${throughput_percentage[i]} * base_throughput1) / 100 ))
	#per_throughput2=$(( (${throughput_percentage[i]} * base_throughput2) / 100 ))
        per_throughput1=$(echo "(${throughput_percentage[i]} * $base_throughput1) / 100" | bc)
        per_throughput2=$(echo "(${throughput_percentage[i]} * $base_throughput2) / 100" | bc)

	echo ${throughput_percentage[i]} $per_throughput1 $per_throughput2
	replacement_rps=${per_throughput1}
	for ((j=2; j<=8; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput1}"
	done
	replacement_rps="--rps ${replacement_rps},${per_throughput2}"
	echo $replacement_rps
	./set_rps.sh /my_mount/eRPC/apps/openloop_exponential/config "$replacement_rps" 	
	#total_throughput=$((base_throughput1 * 8 * throughput_percentage[i] + base_throughput2 * throughput_percentage[i]))
	#total_throughput=$((total_throughput / 100))
        total_throughput=$(echo "($base_throughput1 * 8 * ${throughput_percentage[i]} + $base_throughput2 * ${throughput_percentage[i]}) / 100" | bc)
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
	echo "start $dispatcher_policy ${throughput_percentage[i]} testing..."
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "likwid-powermeter sudo $path/start_test.sh $worker_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling > $cpu_log 2>&1 &"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh $worker_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling false hash.json > $cpu_log 2>&1 &"
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
folder_name=$dispatcher_policy"-$flag"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
mkdir $folder_name
mv ../client-*.log $folder_name
