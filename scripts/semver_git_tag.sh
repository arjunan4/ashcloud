#!/bin/bash

# parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

# cd "$parent_path"

cd ../

FILE='semver-bump.txt'

if [ ! -f "$FILE" ]; then
    echo "$FILE does NOT exist"
    # exit 1
fi
actual_lines=$(< "$FILE" wc -l | sed -e 's/^[ \t]*//')
echo "Actual_number_of_lines =>$actual_lines"

if [ "$actual_lines" != 0 ]; then
    echo "Multiple line exists in $FILE file"
fi

n=0
while read line || [ -n "$line" ] ; 
do 
echo "Line No. $n : $line" 
n=$((n+1))
done < $FILE

