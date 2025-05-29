#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU, EDF_INTERRUPT, DARC or Sledge] [client threads count]"
        exit 1
}

if [ $# != 2 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.218.253"

echo "openloop_exponential" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

disable_busy_loop="true"
disable_preempt="true"
disable_get_req_from_GQ="true"
scheduler="EDF"
dispatcher_policy=$1
if [ "$dispatcher_policy" = "Sledge" ]; then
    #dispatcher_policy="LLD"
    dispatcher_policy="TO_GLOBAL_QUEUE"
    scheduler="FIFO"
    disable_preempt="false"
    disable_get_req_from_GQ="false"
    disable_busy_loop="false"
fi

worker_count=$2
json_file="hash.json"
server_workers=6
path="/my_mount/sledge-serverless-framework/runtime/tests"

flag="exponential-$worker_count"
base_throughput=4000

if [ "$dispatcher_policy" == "SHINJUKU" ]; then
    sed -i 's/--is_darc=[^ ]*/--is_darc=false/g' /my_mount/eRPC/apps/openloop_exponential/config
    throughput_percentage=(10 20 30 40 50 60 70 80 90 100 104 108 110 111 112 113) 
    #throughput_percentage=(10 20) 
elif [ "$dispatcher_policy" == "DARC" ]; then
    sed -i 's/--is_darc=[^ ]*/--is_darc=true/g' /my_mount/eRPC/apps/openloop_exponential/config
    throughput_percentage=(10 20 30 40 50 60 62 64 65 67 68 69 70)
    #throughput_percentage=(80)
    json_file="hash_darc.json"
    reserve_workers=$(($server_workers / 2))
    ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/sed_json.sh $path/$json_file $reserve_workers $reserve_workers"
elif [ "$dispatcher_policy" == "TO_GLOBAL_QUEUE" ]; then
    sed -i 's/--is_darc=[^ ]*/--is_darc=false/g' /my_mount/eRPC/apps/openloop_exponential/config
    throughput_percentage=(10 20 30 40 50 60 70 80 90 100 110 116 118 119 120)
else
    sed -i 's/--is_darc=[^ ]*/--is_darc=false/g' /my_mount/eRPC/apps/openloop_exponential/config
    throughput_percentage=(10 20 30 40 50 60 70 80 90 100 110 116 118 119 120 121)
fi

#throughput_percentage=(71)

req_type="--req_type "
for i in $(seq $worker_count); do
    req_type+="1,"
done

req_type=${req_type%,}

echo $req_type

sed -i "s/^--req_type.*/$req_type/" /my_mount/eRPC/apps/openloop_exponential/config

for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        per_throughput=$(echo "(${throughput_percentage[i]} * $base_throughput) / 100" | bc)

	echo ${throughput_percentage[i]} $per_throughput
	replacement_rps=${per_throughput}
	for ((j=1; j<$worker_count; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput}"
	done
        replacement_rps="--rps ${replacement_rps}"
        sed -i "s/^--rps.*/$replacement_rps/" /my_mount/eRPC/apps/openloop_exponential/config
	echo $replacement_rps
        total_throughput=$(echo "($base_throughput * $worker_count * ${throughput_percentage[i]} / 100)" | bc)
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
        echo $client_log
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
	echo "start $dispatcher_policy ${throughput_percentage[i]} testing..."
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "likwid-powermeter sudo $path/start_test.sh $worker_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling > $cpu_log 2>&1 &"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh $server_workers 1 3 $dispatcher_policy $scheduler $server_log $disable_busy_loop false $disable_get_req_from_GQ $disable_preempt $json_file > $cpu_log 2>&1 &"
	#echo "start cpu monitoring"
	#ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/start_monitor.sh $cpu_log > /dev/null 2>&1 &"
	sleep 10
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
