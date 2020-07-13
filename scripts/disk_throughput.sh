###       Checking Disk throughput       ###
### Called from diskthroughput_check.yml ###
#!/bin/bash

CRIODOCKERINSTALLPATH=/var/lib/docker

dd if=/dev/zero of=${CRIODOCKERINSTALLPATH}/testfile bs=1G count=1 oflag=dsync &> output

res=$(cat output | tail -n 1 | awk '{print $6}')
# writing this since bc may not be default support in customer environment
echo $res | grep -E -o "[0-9]+" | head -n 1
