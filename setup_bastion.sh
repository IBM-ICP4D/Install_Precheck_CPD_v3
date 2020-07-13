### Setup bastion node for ansible.
### Install akirak.coreos-python role. 
### Use "-r" as argument to remove the role.

#!/bin/bash

if [[ $1 == "-r" ]]; then
   ansible-galaxy remove akirak.coreos-python
else
   ansible-galaxy install akirak.coreos-python
fi

