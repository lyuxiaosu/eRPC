import sys
import os

def generate_config(loop_count):
    loop_count = int(loop_count)
    type1 = "1"
    type2 = "2"
    
    config = []
    config.append("--test_ms 10000")
    config.append("--sm_verbose 0")
    config.append("--num_server_threads 1")
    config.append("--window_size 1")
    config.append("--req_size 4")
    config.append("--resp_size 32")
    config.append("--num_processes 2")
    config.append("--numa_0_ports 0")
    config.append("--numa_1_ports 1,3")
    req_type1 = [type1] * (loop_count // 2)
    req_type2 = [type2] * (loop_count // 2)
    config.append("--req_type " + ",".join(req_type1) + "," + ",".join(req_type2))
    config.append("--req_parameter 1,32")
    return "\n".join(config)

if len(sys.argv) != 2:
    print("Usage: <loop_count>")
    sys.exit(1)

loop_count = sys.argv[1]

config_content = generate_config(loop_count)
with open("config", "w") as f:
    f.write(config_content)

