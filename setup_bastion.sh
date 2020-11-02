### Setup bastion node for ansible.
### Install akirak.coreos-python role. 
### Use "-r" as argument to remove the role.

#!/bin/bash

### Setup ansible on bastion - x86_64 platform
setup_x86_bastion()
{
   yum install -y python-netaddr
   yum install -y iperf3
   setup_ansible_role
   cat pypy/pypy-5.6-linux_x86_64-portable.tar.bz2.parta? > pypy/pypy-5.6-linux_x86_64-portable.tar.bz2
}

### Setup Core Nodes - x86_64 platform
setup_x86_core()
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

### Setup ansible on bastion - PowerPC platform
setup_ppc_bastion()
{
   yum install -y python-netaddr
   yum install -y iperf3
   setup_ansible_role
   yum install -y ./ppc64le/python_ppc/python36-3.6.8-2.module+el8.1.0+3334+5cb623d7.ppc64le.rpm \
       ./ppc64le/python_ppc/python3-pip-9.0.3-16.el8.noarch.rpm \
       ./ppc64le/python_ppc/python3-setuptools-39.2.0-5.el8.noarch.rpm

   export PATH=~/.local/bin:$PATH
   python3 -m pip install --user ./ppc64le/ansible_ppc/wheel-0.35.1.tar.gz \
            ./ppc64le/ansible_ppc/pip-20.2.3.tar.gz
   
   python3 -m pip install --user ./ppc64le/ansible_ppc/MarkupSafe-1.1.1.tar.gz \
            ./ppc64le/ansible_ppc/PyYAML-5.3.1.tar.gz \
            ./ppc64le/ansible_ppc/ansible-2.10.0.tar.gz \
            ./ppc64le/ansible_ppc/ansible-base-2.10.2.tar.gz \
            ./ppc64le/ansible_ppc/Jinja2-2.11.2-py2.py3-none-any.whl \
            ./ppc64le/ansible_ppc/packaging-20.4-py2.py3-none-any.whl \
            ./ppc64le/ansible_ppc/pyparsing-2.4.7-py2.py3-none-any.whl
            
   python3 -m pip install --user ./ppc64le/ansible_ppc/netaddr-0.8.0-py2.py3-none-any.whl \
            ./ppc64le/ansible_ppc/importlib_resources-3.0.0-py2.py3-none-any.whl \
            ./ppc64le/ansible_ppc/zipp-3.3.0-py3-none-any.whl
}

### Setup Core Nodes - PowerPC platform
### Mase sure run it after execute setup_ppc_bastion()
setup_ppc_core()
{
   for node in `awk '/\[core\]/{f=1}f' hosts_openshift | awk '{if ($5 == "ansible_ssh_user=core") print $1}'`
   do 
      echo ""
      echo Preparing: $node
      scp pypy/pypy3.6-v7.3.1-ppc64le.tar.bz2 core@$node:~/
      ssh core@$node tar xjvf pypy3.6-v7.3.1-ppc64le.tar.bz2 > /dev/null

      #Copy Python from bastion to core nodes
      ssh core@$node mkdir /var/home/core/bin
      scp /usr/bin/python3 core@$node:/var/home/core/bin
   done
}

setup_ansible_role()
{
echo "
---
# Installing role from local file
- name: akirak.coreos-python
  src: file://`pwd`/ansible_roles/master.tar.gz
" > requirements.yml
ansible-galaxy install -r requirements.yml
}

### Setup Bastion Node
export PATH=~/.local/bin:$PATH

if ! [[ -x "$(command -v ansible)" ]] && [[ `uname -p` == "x86_64" ]]; then
   echo "Error: ansible is not installed. Use 'yum install ansible' to install it." >&2
   exit 1
else
   if [[ $1 == "-r" ]]; then
      ansible-galaxy remove akirak.coreos-python
   else
      if [[ `uname -p` == "ppc64le" ]]; then
         setup_ppc_bastion
         setup_ppc_core
      else # for x86_64
         setup_x86_bastion
         setup_x86_core
      fi
   fi
fi
