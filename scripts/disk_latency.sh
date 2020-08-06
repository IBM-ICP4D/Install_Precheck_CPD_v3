###       Checking Disk latency       ###
### Called from disklatency_check.yml ###
#!/bin/bash

CRIODOCKERINSTALLPATH=/var/lib/docker

sudo dd if=/dev/zero of=${CRIODOCKERINSTALLPATH}/testfile bs=512 count=1000 oflag=dsync  &> output
res=$(cat output | tail -n 1 | awk '{print $8}')
# writing this since bc may not be default support in customer environment
out=$(echo $res | grep -E -o "[0-9]+" | head -n 1)
echo -e "${out}"

