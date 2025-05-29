# When use real world app to test, need to append "--initial-memory=655360" to 
# WASMLDFLAGS of the Makefile in the function code under wasm_apps. This guarantees 
# all moduels have the same initial memory size.
#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU or EDF_INTERRUPT, DARC or Sledge]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

echo "openloop_realapps" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

chmod 400 ./id_rsa
remote_ip="128.110.218.253"

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

req_parameter="--req_parameter 1,120"
sed -i "s/^--req_parameter.*/$req_parameter/" /my_mount/eRPC/apps/openloop_realapps/config

req_type="--req_type 1,1,1,2,2,2"
sed -i "s/^--req_type.*/$req_type/" /my_mount/eRPC/apps/openloop_realapps/config

base_throughput=710

if [ "$dispatcher_policy" == "DARC" ]; then
        throughput_percentage=(1 10 20 30 40 50 60 70 80 81 82 83 84 85 86)
elif [ "$dispatcher_policy" == "SHINJUKU" ]; then
        throughput_percentage=(1 10 20 30 40 50 60 70 80 86 88 90 92 94 95 96)
elif [ "$dispatcher_policy" == "EDF_INTERRUPT" ]; then
        throughput_percentage=(1 10 20 30 40 50 60 70 80 86 88 90 92 94 96 98 99)
elif [ "$dispatcher_policy" == "TO_GLOBAL_QUEUE" ]; then
	#fixed interval = 1ms
        #throughput_percentage=(1 10 20 30 40 50 60 70 80 86 88 90 92 94 96 97 98)
	#fixed interval = 15us
	throughput_percentage=(1 10 20 30 40 50 60 70)
fi

throughput_percentage=(62 64 66 68)
path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#throughput_percentage[@]};i++ )) do
	echo "i is $i"
        #per_throughput=$(( (${throughput_percentage[i]} * base_throughput) / 100 ))
	per_throughput=$(echo "(${throughput_percentage[i]} * $base_throughput) / 100" | bc)
	echo ${throughput_percentage[i]} $per_throughput
	replacement_rps=${per_throughput}
	for ((j=2; j<=6; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput}"
	done
	replacement_rps="--rps ${replacement_rps}"
	echo "$replacement_rps"
	./set_rps.sh /my_mount/eRPC/apps/openloop_realapps/config "$replacement_rps" 	
        #total_throughput=$((base_throughput * 10 * throughput_percentage[i]))
        total_throughput=$(echo "${base_throughput} * 10 * ${throughput_percentage[i]} / 100" | bc)
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
	echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/sed_json.sh $path/high_bimodal_realapps.json 1 5"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 6 1 3 $dispatcher_policy $scheduler $server_log $disable_busy_loop true $disable_get_req_from_GQ $disable_preempt high_bimodal_realapps.json > 1.txt 2>&1 &"
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
folder_name="high_bimodal_realapps_${dispatcher_policy}"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
mkdir $folder_name
mv ../client-*.log $folder_name
