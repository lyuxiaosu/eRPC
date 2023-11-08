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
remote_ip="128.110.218.245"

dispatcher_policy=$1
#base_throughput1=32344
#base_throughput2=32344
base_throughput1=16000
base_throughput2=16000

#throughput_percentage=(10 20 30 40 50 60)
#throughput_percentage=(1 5 10 15)
#for EDF_INTERRUPT
#throughput_percentage=(1 5 10 15 20 25 30 35 40 42)
#for shinjuku
#throughput_percentage=(1 5 10 15 20 25 26 27 28 29 30)
throughput_percentage=(28 29 30 35 40)


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
	./set_rps.sh /users/xiaosuGW/eRPC/apps/openloop_exponential/config "$replacement_rps" 	
	total_throughput=$((base_throughput1 * 8 * throughput_percentage[i] + base_throughput2 * throughput_percentage[i]))
	total_throughput=$((total_throughput / 100))
	server_log="server-${total_throughput}-${throughput_percentage[i]}.log"
	client_log="client-${total_throughput}-${throughput_percentage[i]}.log"
	echo "start $dispatcher_policy ${throughput_percentage[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh 9 3 4 $dispatcher_policy  $server_log > 1.txt 2>&1 &"
        pushd ../
        #scripts/do.sh 1 0 > client.txt
        scripts/do.sh 1 0 $client_log
        popd
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
        sleep 10
done
folder_name=$dispatcher_policy
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"
mkdir $folder_name
mv ../client-*.log $folder_name
