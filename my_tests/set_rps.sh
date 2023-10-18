#!/bin/bash

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <file_path> <replacement_text>"
    exit 1
fi

file_path="$1"
replacement_text="$2"

if [ ! -f "$file_path" ]; then
    echo "No such file: $file_path"
    exit 1
fi

line_count=$(wc -l < "$file_path")

if [ "$line_count" -lt 3 ]; then
    echo "File is too short, no last third line to replace."
    exit 1
fi

# Calculate the line number of the last third line
line_number=$((line_count - 2))

# Use sed to replace the line in-place
sed -i "${line_number}s/.*/$replacement_text/" "$file_path"

echo "After replacement, the last third line is: $replacement_text"
