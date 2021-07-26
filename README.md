# Install_Precheck_CPD_v3
# Description
This project contains a set of pre-installation checks designed to validate that your system is compatible with RedHat Openshift 4.x and Cloud Pak for Data 3.0.1, 3.5.x installations.
# Setup
1. CLONE git repository
```
git clone https://github.com/IBM-ICP4D/Install_Precheck_CPD_v3.git
```
2. GO to Install_Precheck_CPD_v3 directory
```
cd Install_Precheck_CPD_v3
```
3. SET UP hosts_openshift inventory file according to the cluster. A sample_hosts_openshift file is provided.
```
vi hosts_openshift
```
	
sample_hosts_openshift file:
```
[bastion]
bastion_node_name private_ip=XXX.XXX.XXX.XXX name=bastion type=bastion ansible_ssh_user=root

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

#THE [ROOT] GROUP IS FOR USERS WHO HAVE MACHINES THAT DO NOT RUN COREOS. IF THE MACHINES IN YOUR
#CLUSTER ALL USE COREOS(I.E. OPENSHIFT 4.x), THEN YOU MAY LEAVE THIS GROUP COMMENTED OUT OR DELETED.
#IF YOUR MACHINES DO NOT RUN COREOS, YOU WILL NEED TO:
# 1. UNCOMMENT THE [ROOT] GROUP
# 2. COMMENT OUT OR DELETE THE [CORE] GROUP
# 3. CHANGE THE ANSIBLE_SSH_USER FIELDS OF YOUR [MASTER] AND [WORKER] GROUPS TO root

#[root]
#master0_node_name private_ip=10.87.103.68 name=master-01 type=master ansible_ssh_user=root
#master1_node_name private_ip=10.87.103.123 name=master-02 type=master ansible_ssh_user=root
#master2_node_name private_ip=10.87.103.121 name=master-03 type=master ansible_ssh_user=root
#worker0_node_name private_ip=10.87.103.117 name=worker-01 type=worker ansible_ssh_user=root
#worker1_node_name private_ip=10.87.103.108 name=worker-02 type=worker ansible_ssh_user=root
#worker2_node_name private_ip=10.87.103.96 name=worker-03 type=worker ansible_ssh_user=root

[core:vars]
ansible_ssh_user=core
# IF PROCESSOR TYPE IS x86_64 UNCOMMENT FOLLOWING LINE 
ansible_python_interpreter=/var/home/core/pypy/bin/pypy
# IF PROCESSOR TYPE IS ppc64le UNCOMMENT FOLLOWING LINE 
#ansible_python_interpreter=/var/home/core/bin/python3
```
Example Cluster:
- RHCOS master node named master0.example.com with ip address=10.87.103.97
- RHCOS worker node named worker0.example.com with ip address=10.87.103.100
- RHEL bastion node named bastion.example.com with ip address=10.87.103.98

Example hosts_openshift file:
```
[bastion]
bastion.example.com private_ip=10.87.103.98 name=bastion type=bastion ansible_ssh_user=root

[master]
master0.example.com private_ip=10.87.103.97 name=master-01 type=master ansible_ssh_user=core

[worker]
worker0.example.com private_ip=10.87.103.100 name=worker-01 type=worker ansible_ssh_user=core

[core:vars]
ansible_ssh_user=core
ansible_python_interpreter=/var/home/core/pypy/bin/pypy
```

4. RUN setup_bastion.sh
```	
./setup_bastion.sh
```
Since RHCOS machines do not have the necessary python libraries to run the pre-checks, this script will prep the machines with an ansible-galaxy role. 
Make sure all coreOS nodes listed under the \[core\] group in your inventory file. 
In addition this script will perform following to prepare all core nodes:
```
scp pypy/pypy-5.6-linux_x86_64-portable.tar.bz2 iperf3-3.1.3-1.fc24.x86_64.rpm core@<coreOS_node_name>:~/
ssh core@<coreOS_node_name> tar xjvf pypy-5.6-linux_x86_64-portable.tar.bz2 
ssh core@<coreOS_node_name> sudo rpm-ostree install iperf3-3.1.3-1.fc24.x86_64.rpm
```

MAKE SURE REBOOT ALL YOUR CORE NODES AFTER INSTALL IPREF.

After you are done with all pre-install checks, you may run following to remove the ansible-galaxy role:
```
./setup_bastion.sh -r
```

5. INSTALL iperf, netaddr

This script utilizes iperf3 and netaddr to complete some of its checks.

Netaddr, a python package used in this script for obtaining ip addresses, can be installed on the bastion machine with:
```
yum install -y python-netaddr
```
The iperf3, a networking utility used in this script for checking the network bandwidth between the bastion and the master node listed at the TOP OF YOUR MASTER GROUP in your inventory file, can be installed on the bastion machine with:
```
yum install -y iperf3
```



# Usage
This script checks if all nodes meet requirements for OpenShift and CPD installation.
 
Arguments: 

	--phase=[pre_ocp|post_ocp|pre_cpd]                       To specify installation type
	
	--host_type=[core|worker|master|bastion|root]            To specify nodes to check (Default is bastion).
	                                                         The valid arguments to --host_type are the names 
								 of the groupings of nodes listed in hosts_openshift.

	--ocp_ver=[311]                               	 	 To specify openshift version (Default is 4.x). 
								 This option should be used if ocp version is 3.11
								 or machines in the cluster are not core machines"

Example Script Calls: 

	./pre_install_chk.sh --phase=pre_ocp

	./pre_install_chk.sh --phase=post_ocp --host_type=core

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
| Node name resolution | All node names should be resolved by DNS | X | | |
| DNS Record and WildCard Entries | \*.apps.\<cluster\>.domain, api.\<cluster\>.domain, api-int.\<cluster\>.domain should point to the load-balancer/bastion IP. etcd-index.\<cluster\>.domain should point to the corresponding master node IP. | X | | |
| SRV DNS record for etcd server | Must have priority 0, weight 10, and port 2380 | X | | |
| AVX2 | AVX2 supported by processor | X | | |
| Resolving hostname via DNS | Hostname resolution enabled | X | X | |
| Hostname in lowercase letters | Hostname must be all lowercase | X | | |
| Default Gateway | Route for default gateway exists | X | | |
| Validate Internet Connectivity | | X | | |
| Valid IPs | | X | | |
| Validate Network Speed between Nodes | At least 1 GB bandwidth | X | | |
| Check subnet | | X | | |
| Disk Type | Must be xfs file system | X | | |
| Unblocked urls | | X | | |
| Clock Sync | Synchronize computer system clock on all nodes within 500ms | | X | |
| Disk Encryption | LUKS enabled | | X | |
| Openshift Version | 3.11, 4.3, 4.5, 4.6| | X | |
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
| Installer build version | Installer version should be higher than build 15 for CPD v.3.1.0 | | | X |
| FIPS enabled | FIPS can be enable but some CPD services may need special handling | | | X |

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
	http://mirrors.portworx.com
	https://raw.github.com
	
One of the pre-openshift tests will check that these are reachable.


# Helpful Links
If certain tests fail, these links should be able to help address some issues:

	https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/install/node-settings.html#node-settings__lb-proxy for changing load balancer timeout settings and compute node docker container settings.
	https://www.ibm.com/support/knowledgecenter/SSEPGG_11.5.0/com.ibm.db2.luw.qb.server.doc/doc/t0008238.html for updating kernel parameters on compute nodes

# Issue
If you find any bugs or issues in the script, please open an issue on this repository and we will address it as soon as possible.
