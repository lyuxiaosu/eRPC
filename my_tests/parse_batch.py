import re
import os
import sys
from collections import defaultdict

seperate_meet_dict = defaultdict(lambda: defaultdict(list))
total_meet_dict = defaultdict(list)

seperate_miss_rate_dict = defaultdict(lambda: defaultdict(list))
total_miss_rate_dict = defaultdict(list)

seperate_99_latency = defaultdict(lambda: defaultdict(list))
seperate_99_9_latency = defaultdict(lambda: defaultdict(list))
seperate_99_99_latency = defaultdict(lambda: defaultdict(list))

seperate_99_slow_down = defaultdict(lambda: defaultdict(list))
seperate_99_9_slow_down = defaultdict(lambda: defaultdict(list))
seperate_99_99_slow_down = defaultdict(lambda: defaultdict(list))

sending_rate_dict = defaultdict(list)
service_rate_dict = defaultdict(list)
load_dict = defaultdict(int)

seperate_sending_rate_dict = defaultdict(lambda: defaultdict(list))
seperate_service_rate_dict = defaultdict(lambda: defaultdict(list))

#get all file names which contain key_str
def file_name(file_dir, key_str):
    print(file_dir, key_str)
    file_list = []
    rps_list = []
    last_num_list = []

    for root, dirs, files in os.walk(file_dir):
        print("file:", files)
        print("root:", root)
        print("dirs:", dirs)
        for file_i in files:
            if file_i.find(key_str) >= 0:
                full_path = os.path.join(os.getcwd() + "/" + root, file_i)
                #print(full_path)
                segs = file_i.split('-')
                if len(segs) < 2:
                  continue
                rps=segs[1]
                print("rps---------", rps)
                rps=rps.split(".")[0]
                file_list.append(full_path)
                rps_list.append(int(rps))
                last_num=segs[2]
                last_num=last_num.split(".")[0]
                last_num_list.append(int(last_num))

    file_list_based_last_num =   sorted(file_list, key = lambda x: int(x.split('-')[-1].split('.')[0]))
    last_num_list = sorted(last_num_list)
    file_list_based_throughput = sorted(file_list, key = lambda x: int(x.split('-')[1].split(".")[0]))
    rps_list = sorted(rps_list)
    #print(file_list_based_last_num)
    print("--------------------------------", rps_list)
    return file_list_based_last_num, file_list_based_throughput, rps_list, last_num_list

def get_values(key, files_list, latency_dict, slow_down_dict, deadline_miss_rate_dict, slow_down_99_9_dict, latency_99_9_dict, slow_down_99_99_dict, latency_99_99_dict):
    index = 0;
    for file_i in files_list:
                cmd='sudo python3 ./parse_single.py %s' % file_i
                rt=os.popen(cmd).read().strip()
                print(rt)
                print("----------parse file ", file_i, "--------------------------------\n")
                # Define regular expressions to match the desired values
                latency_rule = r'99 percentile latency is\s*([\d.]+)'
                miss_rate_rule = r'miss rate\s*([\d.]+)'
                slow_down_rule = r'99 percentile total slow down is\s*([\d.]+)'
                latency_99_9_rule = r'99.9 percentile latency is\s*([\d.]+)'
                slow_down_99_9_rule = r'99.9 percentile total slow down is\s*([\d.]+)'
                latency_99_99_rule = r'99.99 percentile latency is\s*([\d.]+)'
                slow_down_99_99_rule = r'99.99 percentile total slow down is\s*([\d.]+)'

                seperate_99_latency_rule = r'type\s+(\d+)\s+99\s+percentile\s+latency\s+is\s+([\d.]+)'
                seperate_99_9_latency_rule = r'type\s*(\d+)\s*99.9\s*percentile\s*latency\s*is\s*([\d.]+)'
                seperate_99_99_latency_rule = r'type\s*(\d+)\s*99.99\s*percentile\s*latency\s*is\s*([\d.]+)'

                seperate_99_slow_down_rule = r'type\s*(\d+)\s*99\s*percentile\s*slow down\s*is\s*([\d.]+)'
                seperate_99_9_slow_down_rule = r'type\s*(\d+)\s*99.9\s*percentile\s*slow down\s*is\s*([\d.]+)'
                seperate_99_99_slow_down_rule = r'type\s*(\d+)\s*99.99\s*percentile\s*slow down\s*is\s*([\d.]+)'

                sending_service_rate_rule = r'sending rate: (\d+),\s*service rate: (\d+)\s*total requests: (\d+)'

                seperate_sending_service_rate_rule = r"type\s+(\d+)\s+sending rate\s+(\d+)\s+service rate\s+(\d+)\s+total sending\s+(\d+)" 

                # Use the regular expressions to find the values
                latency_match = re.search(latency_rule, rt)
                miss_rate_match = re.search(miss_rate_rule, rt)
                slow_down_match = re.search(slow_down_rule, rt)
                latency_99_9_match = re.search(latency_99_9_rule, rt)
                slow_down_99_9_match = re.search(slow_down_99_9_rule, rt)
                latency_99_99_match = re.search(latency_99_99_rule, rt)
                slow_down_99_99_match = re.search(slow_down_99_99_rule, rt)
                sending_service_rate_match = re.search(sending_service_rate_rule, rt)

                if miss_rate_match:
                    miss_rate_value = 0
                    miss_rate_value = miss_rate_match.group(1)
                    deadline_miss_rate_dict[key].append(float(miss_rate_value))
                # Check if matches were found and extract the values
                if latency_match:
                        latency_value = 0
                        latency_value = latency_match.group(1)
                        print("99th latency is:", latency_value)
                        latency_dict[key].append(latency_value)

                if slow_down_match:
                        slow_down_value = 0
                        slow_down_value = slow_down_match.group(1)
                        print("99th slow down is:", slow_down_value)
                        slow_down_dict[key].append(slow_down_value)

                if latency_99_9_match:
                        latency_value = 0
                        latency_value = latency_99_9_match.group(1)
                        print("99.9th latency is:", latency_value)
                        latency_99_9_dict[key].append(latency_value)

                if slow_down_99_9_match:
                        slow_down_value = 0
                        slow_down_value = slow_down_99_9_match.group(1)
                        print("99.9th slow down is:", slow_down_value)
                        slow_down_99_9_dict[key].append(slow_down_value)

                if latency_99_99_match:
                        latency_value = 0
                        latency_value = latency_99_99_match.group(1)
                        print("99.99th latency is:", latency_value)
                        latency_99_99_dict[key].append(latency_value)

                if slow_down_99_99_match:
                        slow_down_value = 0
                        slow_down_value = slow_down_99_99_match.group(1)
                        print("99.99th slow down is:", slow_down_value)
                        slow_down_99_99_dict[key].append(slow_down_value)

                for match in re.finditer(seperate_99_latency_rule, rt):
                    r_type, latency = match.groups()
                    print("type:", r_type, "99th latency:", latency)
                    seperate_99_latency[key][int(r_type)].append(float(latency))
                
                for match in re.finditer(seperate_99_9_latency_rule, rt):
                    r_type, latency = match.groups()
                    print("type:", r_type, "99.9th latency:", latency)
                    seperate_99_9_latency[key][int(r_type)].append(float(latency))


                for match in re.finditer(seperate_99_99_latency_rule, rt):
                    r_type, latency = match.groups()
                    print("type:", r_type, "99.99th latency:", latency)
                    seperate_99_99_latency[key][int(r_type)].append(float(latency))
                

                for match in re.finditer(seperate_99_slow_down_rule, rt):
                    r_type, slow_down = match.groups()
                    print("type:", r_type, "99th slow down:", slow_down)
                    seperate_99_slow_down[key][r_type].append(float(slow_down))


                for match in re.finditer(seperate_99_9_slow_down_rule, rt):
                    r_type, slow_down = match.groups()
                    print("type:", r_type, "99.9th slow down:", slow_down)
                    seperate_99_9_slow_down[key][r_type].append(float(slow_down))

                for match in re.finditer(seperate_99_99_slow_down_rule, rt):
                    r_type, slow_down = match.groups()
                    print("type:", r_type, "99.99th slow down:", slow_down)
                    seperate_99_99_slow_down[key][r_type].append(float(slow_down))

                for match in re.finditer(seperate_sending_service_rate_rule, rt):
                    r_type, sending_rate, service_rate, total_sending = match.groups()
                    seperate_sending_rate_dict[key][r_type].append(int(sending_rate))
                    seperate_service_rate_dict[key][r_type].append(int(service_rate))
                    if seperate_meet_dict:
                        miss_number = int(total_sending) - int(seperate_meet_dict[key][r_type][index])
                        miss_rate = (miss_number / int(total_sending)) * 100
                        miss_rate = round(miss_rate, 2)
                        seperate_miss_rate_dict[key][r_type].append(miss_rate)       
                    print("type ", r_type, " sending rate ", sending_rate, " service rate ", service_rate, " total sending ", total_sending)
                    
                if sending_service_rate_match:
                    sending_rate = int(sending_service_rate_match.group(1))
                    service_rate = int(sending_service_rate_match.group(2))
                    total_requests = int(sending_service_rate_match.group(3))
                    sending_rate_dict[key].append(sending_rate)
                    service_rate_dict[key].append(service_rate)
                    if total_meet_dict:
                        total_miss = int(total_requests) - int(total_meet_dict[key][index])
                        total_miss_rate = (total_miss / int(total_requests)) * 100
                        total_miss_rate = round(total_miss_rate, 2)
                        total_miss_rate_dict[key].append(total_miss_rate)
                        print("total miss rate:", total_miss_rate)
                    print("Sending Rate:", sending_rate)
                    print("Service Rate:", service_rate)
                index = index + 1

def load_files(file1, file2):
    """
    Check if both files exist. If they do, read and return their contents.
    
    Args:
        file1 (str): Path to the first file.
        file2 (str): Path to the second file.
    
    Returns:
        tuple: total miss dictionary and seperate miss dictionary if both exist, otherwise None.
    """
    seperate_miss_dict = None
    total_miss_dict = None
    if os.path.exists(file1) and os.path.exists(file2):
        try:
            with open(file1, 'r') as f1, open(file2, 'r') as f2:
                content1 = f1.read()
                total_miss_dict = json.loads(content1)
                content2 = f2.read()
                seperate_miss_dict = json.loads(content2)
            return total_miss_dict, seperate_miss_dict 
        except Exception as e:
            print(f"Error reading files: {e}")
    else:
        if not os.path.exists(file1):
            print(f"File not found: {file1}")
        if not os.path.exists(file2):
            print(f"File not found: {file2}")
    return total_miss_dict, seperate_miss_dict
 
if __name__ == "__main__":
    import json
    #file_folders = ['EDF_INTERRUPT']
    #file_folders = ['DARC', 'EDF_INTERRUPT']
    #file_folders = ['EDF_INTERRUPT', 'LLD','SHINJUKU', 'DARC']
    file_folders = ['EDF_INTERRUPT', 'TO_GLOBAL_QUEUE', 'LLD', 'RR', 'JSQ']
    #file_folders = ['SHINJUKU1', 'EDF_INTERRUPT1','DARC1']
    #file_folders = ['EDF_SRSF_INTERRUPT']
    #file_folders = ['EDF_INTERRUPT','EDF_SRSF_INTERRUPT_1']
    #file_folders = ['DARC', 'EDF_SRSF_INTERRUPT']
    #file_folders = ['SHINJUKU']
    #file_folders = ['EDF_INTERRUPT-disable-busy-loop-false-disable-autoscaling-true-9','EDF_INTERRUPT-disable-busy-loop-true-disable-autoscaling-false-9', 'EDF_INTERRUPT-disable-busy-loop-true-disable-autoscaling-true-27', 'EDF_INTERRUPT-disable-busy-loop-true-disable-autoscaling-false-27']
    #file_folders = ['SHINJUKU_exponential','sledge_exponential']
    latency = defaultdict(list)
    slow_down = defaultdict(list)
    slow_down_99_9 = defaultdict(list)
    latency_99_9 = defaultdict(list)
    slow_down_99_99 = defaultdict(list)
    latency_99_99 = defaultdict(list)
    deadline_miss_rate = defaultdict(list)

    rps_list = []

    argv = sys.argv[1:]
    if len(argv) < 2:
        print("usage ", sys.argv[0], "[file key] [file order, 1 is throughput, 2 is last number]")
        sys.exit()

    file_order = argv[1]
    total_meet_dict, seperate_meet_dict = load_files("./total_meet.txt", "./seperate_meet.txt")
    for key in file_folders:
        files_list_based_last_num, files_list_based_throughput, rps_list, last_num_list = file_name(key, argv[0])
        load_dict[key] = rps_list
        if file_order == "1":
            get_values(key, files_list_based_throughput, latency, slow_down, deadline_miss_rate, slow_down_99_9, latency_99_9, slow_down_99_99, latency_99_99)
        else:
            get_values(key, files_list_based_last_num, latency, slow_down, deadline_miss_rate, slow_down_99_9, latency_99_9, slow_down_99_99, latency_99_99)

    print("99 latency:")
    for key, value in latency.items():
        print(key, ":", value)
    print("99 slow down:")
    for key, value in slow_down.items():
        print(key, ":", value)

    js1 = json.dumps(latency)
    f1 = open("99_latency.txt", 'w')
    f1.write(js1)
    f1.close()

    js2 = json.dumps(slow_down)
    f2 = open("99_slow_down.txt", 'w')
    f2.write(js2)
    f2.close()

    js4 = json.dumps(latency_99_9)
    f4 = open("99_9_latency.txt", 'w')
    f4.write(js4)
    f4.close()

    js5 = json.dumps(slow_down_99_9)
    f5 = open("99_9_slow_down.txt", 'w')
    f5.write(js5)
    f5.close()

    js6 = json.dumps(latency_99_99)
    f6 = open("99_99_latency.txt", 'w')
    f6.write(js6)
    f6.close()

    js7 = json.dumps(slow_down_99_99)
    f7 = open("99_99_slow_down.txt", 'w')
    f7.write(js7)
    f7.close()

    js3 = json.dumps(rps_list)
    f3 = open("rps.txt", 'w')
    f3.write(js3)
    f3.close()

    js8 = json.dumps(seperate_99_latency)
    f8 = open("seperate_99_latency.txt", 'w')
    f8.write(js8)
    f8.close()

    js9 = json.dumps(seperate_99_9_latency)
    f9 = open("seperate_99_9_latency.txt", 'w')
    f9.write(js9)
    f9.close()

    js10 = json.dumps(seperate_99_99_latency)
    f10 = open("seperate_99_99_latency.txt", 'w')
    f10.write(js10)
    f10.close()

    js11 = json.dumps(seperate_99_slow_down)
    f11 = open("seperate_99_slow_down.txt", 'w')
    f11.write(js11)
    f11.close()

    js12 = json.dumps(seperate_99_9_slow_down)
    f12 = open("seperate_99_9_slow_down.txt", 'w')
    f12.write(js12)
    f12.close()

    js13 = json.dumps(seperate_99_99_slow_down)
    f13 = open("seperate_99_99_slow_down.txt", 'w')
    f13.write(js13)
    f13.close()

    js14 = json.dumps(sending_rate_dict)
    f14 = open("sending_rate.txt", 'w')
    f14.write(js14)
    f14.close()

    js15 = json.dumps(service_rate_dict)
    f15 = open("service_rate.txt", 'w')
    f15.write(js15)
    f15.close()

    js16 = json.dumps(seperate_service_rate_dict)
    f16 = open("seperate_service_rate.txt", 'w')
    f16.write(js16)
    f16.close()

    js17 = json.dumps(seperate_sending_rate_dict)
    f17 = open("seperate_sending_rate.txt", 'w')
    f17.write(js17)
    f17.close()

    js18 = json.dumps(deadline_miss_rate)
    f18 = open("miss_rate.txt", 'w')
    f18.write(js18)
    f18.close()

    js19 = json.dumps(load_dict)
    f19 = open("load.txt", 'w')
    f19.write(js19)
    f19.close()

    js20 = json.dumps(seperate_miss_rate_dict)
    f20 = open("seperate_miss_rate.txt", 'w')
    f20.write(js20)
    f20.close()

    js21 = json.dumps(total_miss_rate_dict)
    f21 = open("total_miss_rate.txt", 'w')
    f21.write(js21)
    f21.close()

    js22 = json.dumps(last_num_list)
    f22 = open("last_num.txt", 'w')
    f22.write(js22)
    f22.close()

