#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU or EDF_INTERRUPT or DARC] [disable busy loop, true or false] [disable autoscaling] [client threads count]"
        exit 1
}

if [ $# != 4 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.219.0"

echo "openloop_log_normal" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

dispatcher_policy=$1
disable_busy_loop=$2
disable_autoscaling=$3
worker_count=$4

flag="log-normal-$worker_count"
base_throughput=100

#throughput_percentage=(10 20 30 40 50 60)
#throughput_percentage=(1 5 10 15)
#for EDF_INTERRUPT
#throughput_percentage=(1 5 10 15 20 25 30 35 40 42)
#throughput_percentage=(44 46 48 50 52)
#for shinjuku
#throughput_percentage=(1 5 10 15 20 21 22 23 24 26 28 30 32 34 36 38 40 42 44 46 48 50 52 54)
throughput_percentage=(1 10 20 30 40 50 60 70 80 90 100 110 120 130 140 142 143 144 145 146 147 148)


#for sledge 
#throughput_percentage=(1 5 10 15 20 25 30 35 40 41 42 43 44 46 48 50)
#throughput_percentage=(55 56 57 58)

path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"

req_type="--req_type "
for i in $(seq $worker_count); do
    req_type+="1,"
done

req_type=${req_type%,}

echo $req_type

sed -i "s/^--req_type.*/$req_type/" /my_mount/eRPC/apps/openloop_log_normal/config

for(( i=0;i<${#throughput_percentage[@]};i++ )) do
	per_throughput=$(echo "(${throughput_percentage[i]} * $base_throughput) / 100" | bc)
        echo ${throughput_percentage[i]} $per_throughput
	replacement_rps=${per_throughput}
	for ((j=1; j< $worker_count; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput}"
	done
	replacement_rps="--rps ${replacement_rps}"
	echo $replacement_rps
	./set_rps.sh /my_mount/eRPC/apps/openloop_log_normal/config "$replacement_rps" 	
	total_throughput=$(echo "($base_throughput * $worker_count * ${throughput_percentage[i]} / 100)" | bc)
        server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
	echo "start $dispatcher_policy ${throughput_percentage[i]} testing..."
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "likwid-powermeter sudo $path/start_test.sh $worker_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling > $cpu_log 2>&1 &"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 5 1 3 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling "false" "hash.json" > $cpu_log 2>&1 &"
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
