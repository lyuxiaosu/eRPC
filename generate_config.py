import sys
import os

def generate_config(type1_con, type2_con, type1_rps, type2_rps, type1_param, type2_param):
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
    if type1_con == 0:
        rps2 = [type2_rps] * type2_con
        config.append("--rps " + ",".join(rps2))
        req_type2 = [type2] * type2_con
        config.append("--req-type " + ",".join(req_type2))
        config.append("--req_parameter " + type2_param)
    elif type2_con == 0:
        rps1 = [type1_rps] * type1_con
        config.append("--rps " + ",".join(rps1))
        req_type1 = [type1] * type1_con
        config.append("--req-type " + ",".join(req_type1))
        config.append("--req_parameter " + type1_param)
    else:
        rps1 = [type1_rps] * type1_con
        rps2 = [type2_rps] * type2_con
        parameter1 = [type1_param] * type1_con
        parameter2 = [type2_param] * type2_con
        config.append("--rps " + ",".join(rps1) + "," + ",".join(rps2))
        req_type1 = [type1] * type1_con 
        req_type2 = [type2] * type2_con
        config.append("--req_type " + ",".join(req_type1) + "," + ",".join(req_type2))
        config.append("--req_parameter " + type1_param + "," + type2_param)
    return "\n".join(config)

if len(sys.argv) != 7:
    print("Usage: <type1_concurrency> <type2_concurrency> <type1_rps> <type2_rps> <type1_param> <type2_param>")
    sys.exit(1)

type1_con = int(sys.argv[1])
type2_con = int(sys.argv[2])
type1_rps = sys.argv[3]
type2_rps = sys.argv[4]
type1_param = sys.argv[5]
type2_param = sys.argv[6]

config_content = generate_config(type1_con, type2_con, type1_rps, type2_rps, type1_param, type2_param)
with open("config", "w") as f:
    f.write(config_content)

