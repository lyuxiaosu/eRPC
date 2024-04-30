#!/bin/bash
function usage {
        echo "$0"
        exit 1
}

if [ $# != 0 ] ; then
        usage
        exit 1;
fi

rps=60000
chmod 400 ./id_rsa
remote_ip="128.110.219.0"

concurrency=(1 10 20 24 28 30 32)
#concurrency=(1)

path="/my_mount/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#concurrency[@]};i++ )) do
	echo "i is $i"
        per_thread_types=1
        per_rps=$(($rps / ${concurrency[i]}))
        python3 ../generate_config.py ${concurrency[i]} 0 $per_rps 0 1 0 1 1 $per_thread_types
        cp config ../apps/function_density/
	client_log="client-${concurrency[i]}.log"
        echo "start sledge server for concurrency ${concurrency[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "python3 $path/generate_json.py ${concurrency[i]}"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "mv config.json $path/"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_func_density_test.sh 1 1 5 > 1.txt 2>&1 &"
        sleep 10 
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
