### Setup bastion node for ansible.
### Install akirak.coreos-python role. 
### Use "-r" as argument to remove the role.

#!/bin/bash

if [[ $1 == "-r" ]]; then
   ansible-galaxy remove akirak.coreos-python
else
   ansible-galaxy install akirak.coreos-python
   cat pypy/pypy-5.6-linux_x86_64-portable.tar.bz2.parta? > pypy/pypy-5.6-linux_x86_64-portable.tar.bz2
fi
