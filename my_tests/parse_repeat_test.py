import re
import os
import sys
from collections import defaultdict
import numpy as np

seperate_99_latency = defaultdict(lambda: defaultdict(list))
seperate_99_9_latency = defaultdict(lambda: defaultdict(list))
seperate_99_99_latency = defaultdict(lambda: defaultdict(list))

seperate_99_slow_down = defaultdict(lambda: defaultdict(list))
seperate_99_9_slow_down = defaultdict(lambda: defaultdict(list))
seperate_99_99_slow_down = defaultdict(lambda: defaultdict(list))

sending_rate_dict = defaultdict(list)
service_rate_dict = defaultdict(list)

seperate_sending_rate_dict = defaultdict(lambda: defaultdict(list))
seperate_service_rate_dict = defaultdict(lambda: defaultdict(list))

#get all file names which contain key_str
def file_name(file_dir, key_str):
    print(file_dir, key_str)
    file_list = []
    rps_list = []

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
                rps_list.append(rps)

    file_list = sorted(file_list, key = lambda x: int(x.split('-')[-1].split(".")[0]))
    rps_list = sorted(rps_list)
    print(file_list)
    print(rps_list)
    return file_list, rps_list

def get_values(key, files_list, latency_dict, slow_down_dict, slow_down_99_9_dict, latency_99_9_dict, slow_down_99_99_dict, latency_99_99_dict):
        for file_i in files_list:
                cmd='sudo python3 ./parse_single.py %s' % file_i
                rt=os.popen(cmd).read().strip()
                print(rt)
                print("----------parse file ", file_i, "--------------------------------\n")
                # Define regular expressions to match the desired values
                latency_rule = r'99 percentile latency is\s*([\d.]+)'
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

                sending_service_rate_rule = r'sending rate: (\d+),\s*service rate: (\d+)'

                seperate_sending_service_rate_rule = r"type\s+(\d+)\s+sending rate\s+(\d+)\s+service rate\s+(\d+)" 

                # Use the regular expressions to find the values
                latency_match = re.search(latency_rule, rt)
                slow_down_match = re.search(slow_down_rule, rt)
                latency_99_9_match = re.search(latency_99_9_rule, rt)
                slow_down_99_9_match = re.search(slow_down_99_9_rule, rt)
                latency_99_99_match = re.search(latency_99_99_rule, rt)
                slow_down_99_99_match = re.search(slow_down_99_99_rule, rt)
                sending_service_rate_match = re.search(sending_service_rate_rule, rt)

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
                    seperate_99_slow_down[key][r_type].append(float(latency))


                for match in re.finditer(seperate_99_9_slow_down_rule, rt):
                    r_type, slow_down = match.groups()
                    print("type:", r_type, "99.9th slow down:", slow_down)
                    seperate_99_9_slow_down[key][r_type].append(float(latency))

                for match in re.finditer(seperate_99_99_slow_down_rule, rt):
                    r_type, slow_down = match.groups()
                    print("type:", r_type, "99.99th slow down:", slow_down)
                    seperate_99_99_slow_down[key][r_type].append(float(latency))

                for match in re.finditer(seperate_sending_service_rate_rule, rt):
                    r_type, sending_rate, service_rate = match.groups()
                    print("type ", r_type, " sending rate ", sending_rate, " service rate ", service_rate)
                    seperate_sending_rate_dict[key][r_type].append(int(sending_rate))
                    seperate_service_rate_dict[key][r_type].append(int(service_rate))
                if sending_service_rate_match:
                    sending_rate = int(sending_service_rate_match.group(1))
                    service_rate = int(sending_service_rate_match.group(2))
                    sending_rate_dict[key].append(sending_rate)
                    service_rate_dict[key].append(service_rate)
                    print("Sending Rate:", sending_rate)
                    print("Service Rate:", service_rate)

 
if __name__ == "__main__":
    import json
    import shlex
    import subprocess
    #file_folders = ['SHINJUKU', 'SHINJUKU_25', 'DARC', 'EDF_SRSF_INTERRUPT']
    #file_folders = ['SHINJUKU_7', 'SHINJUKU_25', 'DARC', 'EDF_SRSF_INTERRUPT']
    #file_folders = ['SHINJUKU', 'DARC', 'EDF_SRSF_INTERRUPT']
    #file_folders = ['SHINJUKU', 'EDF_SRSF_INTERRUPT']
    #file_folders = ['EDF_INTERRUPT','EDF_SRSF_INTERRUPT_1']
    #file_folders = ['DARC', 'EDF_SRSF_INTERRUPT']
    #file_folders = ['SHINJUKU1', 'SHINJUKU2', 'SHINJUKU3', 'SHINJUKU4', 'SHINJUKU5']
    key_name = 'SHINJUKU'
    file_folders = ['SHINJUKU1', 'SHINJUKU2', 'SHINJUKU3']
    latency = defaultdict(list)
    slow_down = defaultdict(list)
    slow_down_99_9 = defaultdict(list)
    latency_99_9 = defaultdict(list)
    slow_down_99_99 = defaultdict(list)
    latency_99_99 = defaultdict(list)

    rps_list = []

    argv = sys.argv[1:]
    if len(argv) < 1:
        print("usage ", sys.argv[0], "[file key]")
        sys.exit()

    for key in file_folders:
        files_list, rps_list = file_name(key, argv[0])
        get_values(key, files_list, latency, slow_down, slow_down_99_9, latency_99_9, slow_down_99_99, latency_99_99)

    print("99 latency:")
    for key, value in latency.items():
        print(key, ":", value)
    print("99 slow down:")
    for key, value in slow_down.items():
        print(key, ":", value)

    quoted_folder_name = shlex.quote(key_name)
    command = f'mkdir {quoted_folder_name}'
    subprocess.run(command, shell=True, check=True)

    l = len(latency[key_name + "1"])
    print(l)
    for i in range(l):
        temp = []
        for key in file_folders:
            temp.append(float(latency[key][i]))
        np_array = np.array(temp)
        print(temp)
        print(np_array)
        # Calculate the median and its index
        median_value = np.median(np_array)
        median_index = np.where(np_array == median_value)[0][0]
        pick_file_name = "client-" + sending_rate_dict[file_folders[median_index]][i] + "*.log"
        quoted_pick_file_name = shlex.quote(pick_file_name)
        command = f"cp {quoted_pick_file_name} {quoted_folder_name}"
        subprocess.run(command, shell=True, check=True)
        print(np_array)
        print("median is ", median_value, " index is ", median_index, " pick ", file_folders[median_index], " ", i, "th file");

    sys.exit()
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

    js12 = json.dumps(seperate_99_9_latency)
    f12 = open("seperate_99_9_slow_down.txt", 'w')
    f12.write(js12)
    f12.close()

    js13 = json.dumps(seperate_99_99_latency)
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


