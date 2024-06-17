#!/bin/bash
function usage {
        echo "$0"
        exit 1
}

if [ $# != 0 ] ; then
        usage
        exit 1;
fi

echo "closeloop_trap_client" > ../scripts/autorun_app_file
pushd ../
./build.sh
popd

chmod 400 ./id_rsa
remote_ip="128.110.219.9"

con=2
listener=1

path="/my_mount/sledge-serverless-framework/runtime/tests"
  
python3 ../generate_config.py $con 0 1 0 1 1 1 1 
cp config ../apps/closeloop_trap_client/ 
client_log="client.log"
echo "start sledge server..."
ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip "sudo $path/start_test.sh $con $listener 4 EDF_INTERRUPT server.log true true true trap.json > 1.txt 2>&1 &"
sleep 4 
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

ssh -o stricthostkeychecking=no -i ./id_rsa xiaosuGW@$remote_ip  "sudo $path/kill_sledge.sh"
sleep 4 
folder_name="results"
mkdir $folder_name
mv ../client*.log $folder_name
