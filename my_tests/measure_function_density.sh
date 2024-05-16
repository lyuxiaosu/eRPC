#this script measure function density that beyonds 32 types
#!/bin/bash
function usage {
        echo "$0"
        exit 1
}

if [ $# != 0 ] ; then
        usage
        exit 1;
fi

echo "function_density" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

rps=40000
threads=10
per_rps=$(($rps / $threads))
chmod 400 ./id_rsa
remote_ip="128.110.219.9"

concurrency=(40 60 80 100 120 140 160 180)
#concurrency=(180)

path="/my_mount/sledge-serverless-framework/runtime/tests"
for(( i=0;i<${#concurrency[@]};i++ )) do
	echo "i is $i"
        per_thread_types=$((${concurrency[i]} / $threads))
        python3 ../generate_config.py $threads 0 $per_rps 0 1 0 1 1 $per_thread_types 1
        cp config ../apps/function_density/
	client_log="client-${concurrency[i]}.log"
        echo "start sledge server for concurrency ${concurrency[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "python3 $path/generate_json.py ${concurrency[i]}"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "mv config.json $path/"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_func_density_test.sh 1 1 4 > 1.txt 2>&1 &"
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
