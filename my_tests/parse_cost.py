import re
import sys

if len(sys.argv) != 2:
    print("Usage: python script.py <filename>")
    sys.exit(1)

filename = sys.argv[1]

with open(filename, "r") as file:
    lines = file.readlines()

total_cold_time = 0
total_warm_time = 0

count=0
line_index = 0
print(len(lines))
while line_index < len(lines):
    line = lines[line_index]
    match = re.search(r"total connection time (\d+)", line)
    if match:
        time_value = int(match.group(1))
        total_cold_time += time_value
        total_cold_time += float(lines[line_index+1].split()[2])
        total_warm_time += float(lines[line_index+4].split()[2])
        line_index = line_index + 5 
        count += 1
    else:
        line_index += 1

avg_cold_time = total_cold_time / count
avg_warm_time = total_warm_time / count


print("avg cold time ", avg_cold_time)
print("avg warm time ", avg_warm_time)
print("count ", count)

