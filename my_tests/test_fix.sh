#!/bin/bash
function usage {
        echo "$0 [dispatcher policy, SHINJUKU or EDF_INTERRUPT or DARC]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

chmod 400 ./id_rsa
remote_ip="128.110.219.9"

echo "openloop_fixed" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

dispatcher_policy=$1
base_throughput1=24000
base_throughput2=24000

#throughput_percentage=(10 20 30 40 50 60)
#throughput_percentage=(1 5 10 15)
#for EDF_INTERRUPT
#throughput_percentage=(1 10 20 30 40 50 60 70 80 90 100 102 104 106 108 110 112 114 116 118 120 122 124 126)
#for shinjuku and DARC
throughput_percentage=(1 10 20 30 40 50 60 70 80 90 100 102 104)


path="/my_mount/sledge-serverless-framework/runtime/tests"
#path="/my_mount/old_version/sledge-serverless-framework/runtime/tests"
#path="/my_mount/edf_interrupt/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#throughput_percentage[@]};i++ )) do
        per_throughput1=$(( (${throughput_percentage[i]} * base_throughput1) / 100 ))
	per_throughput2=$(( (${throughput_percentage[i]} * base_throughput2) / 100 ))
	echo ${throughput_percentage[i]} $per_throughput1 $per_throughput2
	replacement_rps=${per_throughput1}
	for ((j=2; j<=8; j++))
	do
  		replacement_rps="${replacement_rps},${per_throughput1}"
	done
	replacement_rps="--rps ${replacement_rps},${per_throughput2}"
	echo $replacement_rps
	./set_rps.sh /my_mount/eRPC/apps/openloop_fixed/config "$replacement_rps" 
	total_throughput=$((base_throughput1 * 8 * throughput_percentage[i] + base_throughput2 * throughput_percentage[i]))
	total_throughput=$((total_throughput / 100))
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
	cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
        echo "start server for $dispatcher_policy ${throughput_percentage[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/sed_json.sh $path/hash.json 6 0"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 6 1 3 $dispatcher_policy  $server_log true true false hash.json > 1.txt 2>&1 &"
        #echo "start cpu monitoring"
        #ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "$path/start_monitor.sh $cpu_log > /dev/null 2>&1 &"
        echo "start client..."
	pushd ../
        sleep 10

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
folder_name="fixed_${dispatcher_policy}"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
mkdir $folder_name
mv ../client-*.log $folder_name
