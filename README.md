# cp4d-dg-checks
# Description
This project contains a set of pre-installation checks designed to validate that your system is compatible with RedHat Openshift 4.3.13+ and Cloud Pak 4 Data 3.0.1 installations.
# Setup
1. CLONE git repository
```
git clone https://github.com/dhgaan-ibm/cp4d-dg-checks.git
```
2. GO to cp4d-dg-checks directory
```
cd cp4d-dg-checks
```
3. SET UP hosts_openshift inventory file according to the cluster. A sample_hosts_openshift file is provided.
```
vi hosts_openshift
```
	
Example file:
```
[bastion]
bastion_node_name private_ip=9.30.205.216 name=bastion type=bastion ansible_ssh_user=root

[master]
master0_node_name private_ip=10.87.103.68 name=master-01 type=master ansible_ssh_user=core
master1_node_name private_ip=10.87.103.123 name=master-02 type=master ansible_ssh_user=core
master2_node_name private_ip=10.87.103.121 name=master-03 type=master ansible_ssh_user=core

[worker]
worker0_node_name private_ip=10.87.103.117 name=worker-01 type=worker ansible_ssh_user=core
worker1_node_name private_ip=10.87.103.108 name=worker-02 type=worker ansible_ssh_user=core
worker2_node_name private_ip=10.87.103.96 name=worker-03 type=worker ansible_ssh_user=core

[core]
master0_node_name private_ip=10.87.103.68 name=master-01 type=master ansible_ssh_user=core
master1_node_name private_ip=10.87.103.123 name=master-02 type=master ansible_ssh_user=core
master2_node_name private_ip=10.87.103.121 name=master-03 type=master ansible_ssh_user=core
worker0_node_name private_ip=10.87.103.117 name=worker-01 type=worker ansible_ssh_user=core
worker1_node_name private_ip=10.87.103.108 name=worker-02 type=worker ansible_ssh_user=core
worker2_node_name private_ip=10.87.103.96 name=worker-03 type=worker ansible_ssh_user=core

[core:vars]
ansible_ssh_user=core
ansible_python_interpreter=/var/home/core/pypy/bin/pypy
```
4. RUN setup_bastion.sh
```	
./setup_bastion.sh
```
Since RHCOS machines do not have the necessary python libraries to run the pre-checks, this script will prep the machines with an ansible-galaxy 	install. After you are done with all checks, run:
```
./setup_bastion.sh -r
```
to remove the install.

5. INSTALL iperf, netaddr

This script utilizes iperf3 and netaddr to complete some of its checks.

Netaddr, a python package used in this script for obtaining ip addresses, can be installed on the bastion machine with:
```
yum install -y python-netaddr
```
iperf3, a networking utility used in this script for checking the network bandwidth between the bastion and the master node listed at the TOP OF YOUR MASTER GROUP in your inventory file, can be installed on the bastion machine with:
```
yum install -y iperf3
```
Make sure the core machine you are installing to is the node listed at the top of your \[master\] group in your inventory file. To install on the core master machine, push the iperf3 rpm file included in this directory from the bastion node to the master node's home directory with this command:
```
scp iperf3-3.1.3-1.fc24.x86_64.rpm core@<master_node_name>:~/ 
```
Then run these commands on the core master node to complete the install:
```
sudo rpm-ostree install iperf3-3.1.3-1.fc24.x86_64.rpm
sudo systemctl reboot
```
MAKE SURE IT IS OK TO REBOOT YOUR MACHINE BEFORE RUNNING THE REBOOT COMMAND(i.e. no other users are logged into the machine)

# Usage
This script checks if all nodes meet requirements for OpenShift and CPD installation.
 
Arguments: 

	--phase=[pre_ocp|post_ocp|pre_cpd]                       To specify installation type
	
	--host_type=[core|worker|master|bastion]                 To specify nodes to check (Default is bastion).
	The valid arguments to --host_type are the names of the groupings of nodes listed in hosts_openshift

	--compute=[worker|compute]                               To specify compute nodes as listed in hosts_openshift for kernel parameter checks (Default is worker)

Example Script Calls: 

	./pre_install_chk.sh --phase=pre_openshift

	./pre_install_chk.sh --phase=post_openshift --host_type=core

# Output
This script takes advantage of ansible playbooks to perform its checks.

If any test fails, you can view the results of its playbook in /tmp/preInstallCheckResult

The current value of the variable tested will appear under the 'debug' task for that particular playbook.

# Validation List
| Validation | Requirement | Pre-OCP | Post-OCP | Pre-CPD |
| --- | --- | --- | --- | --- |
| Processor Type | x86_64, ppc64 | X | X | |
| Disk Latency | 50 Kb/sec | X | | |
| Disk Throughput | 1 Gb/sec | X | | |
| DNS Configuration | DNS must be enabled | X | | |
| Resolving hostname via DNS | Hostname resolution enabled | X | X | |
| Default Gateway | Route for default gateway exists | X | | |
| Validate Internet Connectivity | | X | | |
| Valid IPs | | X | | |
| Validate Network Speed | | X | | |
| Check subnet | | X | | |
| Disk Type | Must be xfs file system | X | | |
| Unblocked urls | | X | | |
| Clock Sync | Synchronize computer system clock on all nodes within 500ms | | X | |
| Disk Encryption | LUKS enabled | | X | |
| Openshift Version | at least 4.3.13 | | X | |
| CRI-O Version | at least 1.13 | | X | |
| Timeout Settings (Load Balancer only) | HAProxy timeout should be set to 5 minutes | | X | |
| Max open files on compute | at least 66560 | | X | |
| Max process on compute | at least 12288 | | X | |
| Kernel Virtual Memory on compute | vm.max_map_count>=262144 | | | X |
| Message Limit on compute | kernel.msgmax >= 65536, kernel.msgmnb >= 65536, kernel.msgmni >= 32768 | | | X |
| Shared Memory Limit on compute | kernel.shmmax >= 68719476736, kernel.shmall >= 33554432, kernel.shmmni >= 16384 | | | X |
| Semaphore Limit on compute | kernel.sem >= 250 1024000 100 16384 | | | X |
| Cluster-admin account | | | | X |
| Cluster-admin user must grant the cpd-admin-role to the project administration | | | | X |
| No user group defined under scc anyuid | system:authenticated and system:serviceaccounts should not be in scc anyuid | | | X |

# Unblocked Urls
The machines that are being tested should be be able to reach these links:

	http://registry.ibmcloudpack.com/cpd301/
        https://registry.redhat.io
        https://quay.io
        https://sso.redhat.com
        https://github.com/IBM
        https://cp.icr.io
        https://us.icr.io
        https://gcr.io
        https://k8s.gcr.io
        https://quay.io
        https://docker.io
        https://raw.github.com
        https://myibm.ibm.com
        https://www.ibm.com/software/passportadvantage/pao_customer.html
        https://www.ibm.com/support/knowledgecenter
        http://registry.ibmcloudpack.com/
        https://docs.portworx.com
	
One of the pre-openshift tests will check that these are reachable.


# Helpful Links
If certain tests fail, these links should be able to help address some issues:

	https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/install/node-settings.html#node-settings__lb-proxy for changing load balancer timeout settings and compute node docker container settings.
	https://www.ibm.com/support/knowledgecenter/SSEPGG_11.5.0/com.ibm.db2.luw.qb.server.doc/doc/t0008238.html for updating kernel parameters on compute nodes
