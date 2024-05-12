#server starts 5 workers and client starts 10 threads

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

echo "openloop_tpcc" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

dispatcher_policy=$1
json_file=""

if [ "$dispatcher_policy" == "DARC" ]; then
    sed -i 's/--is_darc=[^ ]*/--is_darc=true/g' /my_mount/eRPC/apps/openloop_tpcc/config
    json_file="dummy_tpcc_DARC.json"
else
    sed -i 's/--is_darc=[^ ]*/--is_darc=false/g' /my_mount/eRPC/apps/openloop_tpcc/config
    json_file="dummy_tpcc_EDF_SHINJUKU.json"
fi

disable_busy_loop=$2
disable_autoscaling=$3
threads_count=$4
group_size=$(($threads_count / 5))

flag="tpcc-$threads_count"
base_throughput1=44000
base_throughput2=4000
base_throughput3=44000
base_throughput4=4000
base_throughput5=4000

#throughput_percentage=(10 20 30 40 50 60 65 70 75 80 81 82 83 84 85 86 87 88 89)
#throughput_percentage=(0.05 0.08 0.1 0.5 0.8 1 4 8 10 20 30 40 50 60 70 80 90 100 110 120 122 123 124 125 126 128)

#for shinjuku 15us quantum, 14 workers
#throughput_percentage=(100 150 200 210 220 230 232 233)
#for shinjuku 15us quantum, 5 workers
#throughput_percentage=(10 20 30 40 50 60 65 70 75 80 81 82 83 84 85 87 89 90 100 110 120 124)
#throughput_percentage=(124.828)
#throughput_percentage=(0.08)

#for EDF_INTERRUPT 14 workers
#throughput_percentage=(100 150 200 210 220 230 232 234 236 238 239 240)
#for EDF_INTERRUPT 5 workers
#throughput_percentage=(10 20 30 40 50 60 70 80 90 100 110 120 130 140 141 142 143 144 145 146)
#for EDF_INTERRUPT 7 workers
throughput_percentage=(185)

#for DARC, 14 workers
#throughput_percentage=(100 150 200 210 220 230 240 245 246)
#for DARC, 7 workers
throughput_percentage=(184)
#for DARC, 5 workers
#throughput_percentage=(10 20 30 40 50 60 65 70 75 80 81 82 83 84 85 86 87 88 88 90 100 110 120 126)

path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"

req_type="--req_type "
for i in {1..5}; do
    for j in $(seq $group_size); do
        req_type+="$i,"
    done
done

req_type=${req_type%,}

echo $req_type

sed -i "s/^--req_type.*/$req_type/" /my_mount/eRPC/apps/openloop_tpcc/config
for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        throughput1=$(echo "(${throughput_percentage[i]} * $base_throughput1) / 100" | bc)
        throughput2=$(echo "(${throughput_percentage[i]} * $base_throughput2) / 100" | bc)
        throughput3=$(echo "(${throughput_percentage[i]} * $base_throughput3) / 100" | bc)
        throughput4=$(echo "(${throughput_percentage[i]} * $base_throughput4) / 100" | bc)
        throughput5=$(echo "(${throughput_percentage[i]} * $base_throughput5) / 100" | bc)

        rps1=$(echo "($throughput1) / $group_size" | bc)
        rps2=$(echo "($throughput2) / $group_size" | bc)
        rps3=$(echo "($throughput3) / $group_size" | bc)
        rps4=$(echo "($throughput4) / $group_size" | bc)
        rps5=$(echo "($throughput5) / $group_size" | bc)

	echo $rps1 $rps2 $rps3 $rps4 $rps5
	replacement_rps="--rps "
        for rps in $rps1 $rps2 $rps3 $rps4 $rps5; do
    	    for j in $(seq $group_size); do
                replacement_rps+="$rps,"
            done
        done
	replacement_rps=${replacement_rps%,}
	echo $replacement_rps
	./set_rps.sh /my_mount/eRPC/apps/openloop_tpcc/config "$replacement_rps" 	
	total_throughput=$(($throughput1 + $throughput2 + $throughput3 + $throughput4 + $throughput5))
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
        echo $client_log
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
	echo "start $dispatcher_policy ${throughput_percentage[i]} testing..."
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "likwid-powermeter sudo $path/start_test.sh $threads_count 3 5 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling > $cpu_log 2>&1 &"
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 14 1 3 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling false $json_file > $cpu_log 2>&1 &"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 7 1 3 $dispatcher_policy  $server_log $disable_busy_loop $disable_autoscaling false $json_file > $cpu_log 2>&1 &"
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
