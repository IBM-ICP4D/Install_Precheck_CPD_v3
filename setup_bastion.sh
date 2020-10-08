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

### Setup ansible on PowerPC platform
setup_ppc()
{
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
if [[ `uname -p` == "ppc64le" ]]; then
   setup_ppc
fi

if ! [[ -x "$(command -v ansible)" ]]; then
   echo "Error: ansible is not installed. Use 'yum install ansible' to install it." >&2
   exit 1
else
   if [[ $1 == "-r" ]]; then
      ansible-galaxy remove akirak.coreos-python
   else
      yum install -y python-netaddr
      yum install -y iperf3
      #tar xzvf ./ansible_roles/master.tar.gz -C ~/.ansible/roles/
      #mv ~/.ansible/roles/ansible-coreos-python-master ~/.ansible/roles/akirak.coreos-python
      setup_ansible_role
      cat pypy/pypy-5.6-linux_x86_64-portable.tar.bz2.parta? > pypy/pypy-5.6-linux_x86_64-portable.tar.bz2
      setup_core
   fi
fi
