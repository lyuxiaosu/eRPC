# When use real world app to test, need to append "--initial-memory=655360" to 
# WASMLDFLAGS of the Makefile in the function code under wasm_apps. This guarantees 
# all moduels have the same initial memory size.
#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU or EDF_INTERRUPT or DARC]"
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
remote_ip="128.110.219.10"

req_parameter="--req_parameter 1,120"
sed -i "s/^--req_parameter.*/$req_parameter/" /my_mount/eRPC/apps/openloop_realapps/config

req_type="--req_type 1,1,1,1,1,2,2,2,2,2"
sed -i "s/^--req_type.*/$req_type/" /my_mount/eRPC/apps/openloop_realapps/config

dispatcher_policy=$1
base_throughput=434
#base_throughput1=16000
#base_throughput2=2000

throughput_percentage=(1 10 20 30 40 50 60 70 80 90 100)
#throughput_percentage=(82 84 86 88 90)
#throughput_percentage=(100)


path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#throughput_percentage[@]};i++ )) do
	echo "i is $i"
        per_throughput=$(( (${throughput_percentage[i]} * base_throughput) / 100 ))
	echo ${throughput_percentage[i]} $per_throughput
	replacement_rps=${per_throughput}
	for ((j=2; j<=10; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput}"
	done
	replacement_rps="--rps ${replacement_rps}"
	echo $replacement_rps
	./set_rps.sh /my_mount/eRPC/apps/openloop_realapps/config "$replacement_rps" 	
        total_throughput=$((base_throughput * 10 * throughput_percentage[i]))
	total_throughput=$((total_throughput / 100))
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
	echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/sed_json.sh $path/high_bimodal_realapps.json 1 5"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 6 1 3 $dispatcher_policy $server_log true true true high_bimodal_realapps.json > 1.txt 2>&1 &"
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
