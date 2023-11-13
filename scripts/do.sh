#!/usr/bin/env bash
# Run an eRPC app on this machine. This script must be run from eRPC homedir.

function usage {
        echo "$0 [process id] [numa node] [client log file]"
        exit 1
}

if [ $# -lt 2 ] ; then
        usage
        exit 1;
fi



source $(dirname $0)/utils.sh

assert_file_exists scripts/autorun_app_file
export autorun_app=`cat scripts/autorun_app_file`

assert_file_exists build/$autorun_app
chmod +x build/$autorun_app # Fix permissions messed up by lsyncd

export CLIENT_PERF_LOG=./client.log
export MLX4_SINGLE_THREADED=1
export MLX5_SINGLE_THREADED=1
export MLX5_SHUT_UP_BF=0
export MLX_QP_ALLOC_TYPE="HUGE"
export MLX_CQ_ALLOC_TYPE="HUGE"

# Check arguments
if [ "$#" -gt 4 ] || [ "$#" -lt 2 ]; then
  blue "Illegal args. Usage: do.sh [process_id] [NUMA node] [client log file] <gdb>"
	exit
fi

epid=$1
numa_node=$2

if [ "$#" -eq 3 ]; then
	export CLIENT_PERF_LOG=$3
fi

# Non-GDB mode
if [ "$#" -eq 2 -o "$#" -eq 3 ]; then
  blue "do.sh: Launching process $epid on NUMA node $numa_node"

  sudo -E env LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
    numactl --cpunodebind=$numa_node --membind=$numa_node \
    ./build/$autorun_app $(cat apps/$autorun_app/config) \
    --process_id $epid --numa_node $numa_node
  app_return_value=$?
  # Explicitly return the app's return value
  exit $app_return_value
fi

# GDB mode
if [ "$#" -eq 4 ]; then
  blue "do.sh: Launching process $epid with GDB"
  sudo -E env LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
    gdb -ex run --args \
    ./build/$autorun_app $(cat apps/$autorun_app/config) \
    --process_id $epid --numa_node $numa_node
fi
