#this script measure function density scaling with worker cores. Deprecated, using measure_function_density_scaling2.sh 
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

threads=10
chmod 400 ./id_rsa
remote_ip="128.110.219.9"

#concurrency1=(40 100 300 500 700 900 1100 1300 1500 1700 1900 2000)
concurrency1=(2000)
concurrency2=(40 100 1100 2100 2300 2500 2700 2900 3100 3300 3500 3700 3900 4000)
concurrency3=(40 100 1100 2100 3100 4100 5100 5300 5500 5700 5900 6000)
#concurrency9=(40 100 1100 3100 5100 7100 9100 11000 13000 15000 17000 18000)
concurrency9=(18000)

path="/my_mount/sledge-serverless-framework/runtime/tests"
function run_tests() {
  local concurrency=("${!1}")
  local worker_count="$2"
  local listener_count="$3"
  local worker_start_idx=$(($listener_count + 2 + 1))
  local total_rps=$((40000 * $worker_count))
  local per_rps=$(($total_rps / $threads))

  for(( i=0;i<${#concurrency[@]};i++ )) do
	echo "doing test for worker count $worker_count concurrency ${concurrency[i]}"
        local func_types=${concurrency[i]}
        python3 ../generate_config.py $threads 0 $per_rps 0 1 0 1 $listener_count $func_types 1
        cp config ../apps/function_density/
	client_log="client-${concurrency[i]}.log"
	server_log="server-${concurrency[i]}.log"
        echo "start sledge server for concurrency ${concurrency[i]} testing..."
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "python3 $path/generate_json_with_replica_field.py ${concurrency[i]} config.json"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "mv config.json $path/"
        ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_func_density_test.sh $worker_count $listener_count $worker_start_idx config.json $server_log > 1.txt 2>&1 &"
        sleep 20 
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

  folder_name="${worker_count}_workers"
  ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mkdir $path/$folder_name"
  ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "mv *.log $path/$folder_name"

  mkdir $folder_name
  mv ../client-*.log $folder_name
}

#run_tests "concurrency1[@]" 1 1 
#run_tests "concurrency2[@]" 2 1 
#run_tests "concurrency3[@]" 3 1 
#run_tests "concurrency9[@]" 9 3 


