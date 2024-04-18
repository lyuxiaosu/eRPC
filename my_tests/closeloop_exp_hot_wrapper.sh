#!/bin/bash
function usage {
        echo "$0 [total expected rps]"
        exit 1
}

if [ $# != 1 ] ; then
        usage
        exit 1;
fi

rps=$1

chmod 400 ./id_rsa
remote_ip="128.110.219.0"

concurrency=(1 2 6 8 10 12 14 16)
#concurrency=(2)

path="/my_mount/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#concurrency[@]};i++ )) do
	echo "i is $i"
        python3 ../generate_config.py ${concurrency[i]} 0 $(($rps / ${concurrency[i]})) 0 1 1 1
        cp config ../apps/closeloop_exponential/ 
	client_log="client-${concurrency[i]}.log"
	#cpu_log="cpu-${total_throughput}-${throughput_percentage[i]}.log"
	echo "start sledge server for concurrency ${concurrency[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start.sh 1 1 5 > 1.txt 2>&1 &"
	sleep 4 
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
        sleep 4 
done
folder_name="results"
mkdir $folder_name
mv ../client-*.log $folder_name
