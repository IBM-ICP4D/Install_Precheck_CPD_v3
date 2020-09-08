### Setup bastion node for ansible.
### Install akirak.coreos-python role. 
### Use "-r" as argument to remove the role.

#!/bin/bash

### Setup Core Nodes
setup_core()
{
   for node in `awk '/\[core\]/{f=1}f' hosts_openshift | awk '{if ($5 == "ansible_ssh_user=core") print $1}'`
   do 
      echo ""
      echo Preparing: $node
      scp pypy/pypy-5.6-linux_x86_64-portable.tar.bz2 iperf3-3.1.3-1.fc24.x86_64.rpm core@$node:~/
      ssh core@$node tar xjvf pypy-5.6-linux_x86_64-portable.tar.bz2 > /dev/null
      ssh core@$node sudo rpm-ostree install iperf3-3.1.3-1.fc24.x86_64.rpm
   done
}

### Setup Bastion Node
if ! [[ -x "$(command -v ansible)" ]]; then
   echo "Error: ansible is not installed. Use 'yum install ansible' to install it." >&2
   exit 1
else
   if [[ $1 == "-r" ]]; then
      ansible-galaxy remove akirak.coreos-python
   else
      yum install -y python-netaddr
      yum install -y iperf3
      ansible-galaxy install akirak.coreos-python
      cat pypy/pypy-5.6-linux_x86_64-portable.tar.bz2.parta? > pypy/pypy-5.6-linux_x86_64-portable.tar.bz2
      setup_core
   fi
fi


