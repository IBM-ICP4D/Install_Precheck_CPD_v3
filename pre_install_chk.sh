#/bin/bash

#output file
OUTPUT="/tmp/preInstallCheckResult"
ANSIBLEOUT="/tmp/preInstallAnsible"

rm -f ${OUTPUT}
rm -f ${ANSIBLEOUT}

#user variables, modify these to change the default hosts you would like this script to run on
hosts=bastion
compute=worker #Used in post_ocp, pre_cpd checks for kernel checks
load_balance=bastion #Used in timeout settings check
core=core #Used in disk_encryption check

#global variables
GLOBAL=(
	https://www.ibm.com/support/knowledgecenter/SSQNUZ_3.0.1/cpd/install/node-settings.html#node-settings__lb-proxy
	3.0.1
	16
       )
OCP_VER=(
	3.11.188
	3.11.200
	3.11.216
	3.11.219
	3.11.232
	4.3.13
	4.3.18 
	4.3.19 
	4.3.21 
	4.3.22 
	4.3.23 
	4.3.24 
	4.3.25 
	4.3.26 
	4.3.27 
	4.3.28 
	4.3.29
	4.5.0 
	4.5.1 
	4.5.2
	)

#These urls should be unblocked. The function check_unblocked_urls will validate that these are reachable
URLS=(
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
    )


function usage(){
    echo ""
    echo -e "\033[0;32mThis script checks if all nodes meet requirements for OpenShift and CPD installation.\033[0m"
    echo ""
    echo -e "\033[0;32mArguments:\033[0m "
    echo "
	--phase=[pre_ocp|post_ocp|pre_cpd]                       To specify installation type"
    echo "	
	--host_type=[core|worker|master|bastion]                 To specify nodes to check (Default is bastion).
								 The valid arguments to --host_type are the names 
  								 of the groupings of nodes listed in hosts_openshift"
    echo "
	--ocp_ver=[311]                               	 	 To specify openshift version (Default is 4.3). 
								 This option should be used if ocp version is 3.11
								 or machines in the cluster are not core machines"
    echo ""
    echo -e "\033[0;34mNOTE: If any test displays a 'Could not match supplied host pattern' warning, you will have to modify the hosts_openshift inventory file so that your nodes are correctly grouped, or utilize the --host_type argument to pass in the correct group of nodes to be tested. 
Some tests are configured to only be ran on certain groups.\033[0m"
    echo ""
    echo -e "\033[0;32mExample Script Calls:\033[0m "
    echo "./pre_install_chk.sh --phase=pre_ocp"
    echo "./pre_install_chk.sh --phase=post_ocp --host_type=core"
    echo ""
    echo -e "\033[0;34mThis script takes advantage of ansible playbooks to perform its checks.
If any test fails, you can view the results of its playbook in ${OUTPUT}
The current value of the variable tested will appear under the 'debug' task for that particular playbook.\033[0m"
    echo ""
}



###############

function log() {
    if [[ "$1" =~ ^ERROR* ]]; then
	eval "$2='\033[91m\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^Running* ]]; then
	eval "$2='\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^WARNING* ]]; then
	eval "$2='\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^NOTE* ]]; then
        eval "$2='\033[1m$1\033[0m'"
    else
	eval "$2='\033[92m\033[1m$1\033[0m'"
    fi
}

function printout() {
    echo -e "$1" | tee -a ${OUTPUT}
}

function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

#################

function check_openshift_version() {
    output=""
    echo -e "\nChecking Openshift Version" | tee -a ${OUTPUT}

    vers=$(oc version | grep "Server Version:" | grep -Eo "([0-9]{1,}\.)+[0-9]{1,}")
    echo "${vers}"
         
    if [[ $(contains "${OCP_VER[@]}" "${vers}") == "n" ]]; then
        log "ERROR: Your version of Openshift is not compatible with Cloud Pak 4 Data. If on 3.11, update to at least 3.11.188. If on 4.3, update to at least version 4.3.13" result
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi

}

function check_crio_version() {
    output=""
    echo -e "\nChecking CRI-O Version. Note: this test is being tested on master nodes." | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l master playbook_311/check_crio_version.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l master playbook_43/check_crio_version.yml > ${ANSIBLEOUT}
    fi
    
    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Version of CRI-O must be at least 1.13." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi

} 

function check_timeout_settings(){
    output=""
    echo -e "\nChecking Timeout Settings on Load Balancer" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${load_balance} playbook_311/check_timeout_settings.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${load_balance} playbook_43/check_timeout_settings.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Your HAProxy client and server timeout settings are below 5 minutes. 
Please update your /etc/haproxy/haproxy.cfg file. 
Visit ${GLOBAL[0]} for update commands" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
 
}

function validate_internet_connectivity(){
    output=""
    echo -e "\nChecking Connection to Internet" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/internet_connect.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/internet_connect.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
	log "ERROR: Could not reach IBM.com. Check internet connection" result
	cat ${ANSIBLEOUT} >> ${OUTPUT}
	ERROR=1
    else
	log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
	printout "$output"
    fi    
}

function validate_ips(){
    output=""
    echo -e "\nChecking for host IP Address" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/validate_ip_addresses.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/validate_ip_addresses.yml > ${ANSIBLEOUT}
    fi
    
    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Host ip is not a valid ip." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function validate_network_speed(){
    output=""
    echo -e "\nChecking network speed" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift playbook_311/check_network_speed.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift playbook_43/check_network_speed.yml > ${ANSIBLEOUT}
    fi

    bandwidth=$(grep '0.00-10.00' ${ANSIBLEOUT} | grep -Eo '[0-9]*\.[0-9]*\sGbits/sec' | awk "NR==11")

    log "NOTE: Bandwidth between bastion and master node is ${bandwidth}" result
    cat ${ANSIBLEOUT} >> ${OUTPUT}
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi

}

function check_subnet(){
    output=""
    echo -e "\nChecking subnet" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/check_subnet.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/check_subnet.yml > ${ANSIBLEOUT}
    fi
    
    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Host ip not in range" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi

}

function check_dnsconfiguration(){
    output=""
    echo -e "\nChecking DNS Configuration" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/dnsconfig_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/dnsconfig_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: DNS is not properly setup. Could not find a proper nameserver in /etc/resolv.conf " result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_processor() {
    output=""
    echo -e "\nChecking Processor Type" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/processor_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/processor_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
	log "ERROR: Processor type must be x86_64 or ppc64" result
	cat ${ANSIBLEOUT} >> ${OUTPUT}
	ERROR=1
    else
	log "[PASSED]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
	printout "$output"
    fi
}

function check_dockerdir_type(){
    output=""
    echo -e "\nChecking XFS FSTYPE for docker storage" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/dockerdir_type_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/dockerdir_type_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Docker target filesystem must be formatted with ftype=1. Please reformat or move the docker location" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_dnsresolve(){
    output=""
    echo -e "\nChecking hostname can resolve via  DNS" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/dnsresolve_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/dnsresolve_check.yml > ${ANSIBLEOUT}
    fi

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
	if [[ `grep 'host: command not found' ${ANSIBLEOUT}` ]]; then
	    log "ERROR: \"host\" command does not exist on this machine. Please install command to run this check." result
	    cat ${ANSIBLEOUT} >> ${OUTPUT}
	    ERROR=1
	else
            log "ERROR: hostname is not resolved via the DNS. Check /etc/resolve.conf " result
            cat ${ANSIBLEOUT} >> ${OUTPUT}
            ERROR=1
        fi
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_gateway(){
    output=""
    echo -e "\nChecking Default Gateway" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/gateway_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/gateway_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: default gateway is not setup " result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_hostname(){
    output=""
    echo -e "\nChecking if hostname is in lowercase characters" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/hostname_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/hostname_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Only lowercase characters are supported in the hostname" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_disklatency(){
    output=""
    echo -e "\nChecking Disk Latency" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/disklatency_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/disklatency_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Disk latency test failed. By copying 512 kB, the time must be shorter than 60s, recommended to be shorter than 10s." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_diskthroughput(){
    output=""
    echo -e "\nChecking Disk Throughput" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/diskthroughput_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/diskthroughput_check.yml > ${ANSIBLEOUT}
    fi
   

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Disk throughput test failed. By copying 1.1 GB, the time must be shorter than 35s, recommended to be shorter than 5s" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_unblocked_urls(){
    output=""
    echo -e "\nChecking connectivity to required links. This test should take a couple minutes" | tee -a ${OUTPUT}
    BLOCKED=0
    for i in "${URLS[@]}"
    do
       :
       if [[ ${OCP_311} -eq 1 ]] ; then
    	   ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/url_check.yml -e "url=$i" > ${ANSIBLEOUT}
       else 
	   ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/url_check.yml -e "url=$i" > ${ANSIBLEOUT}
       fi
       

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "WARNING: $i is not reachable. Enabling proxy might fix this issue." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        WARNING=1
        BLOCKED=1
        printout "$result"
    fi
    done

    if [[ ${BLOCKED} -eq 0 ]]; then
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"
   
    if [[ ${LOCALTEST} -eq 1 && ${BLOCKED} -eq 0 ]]; then
        printout "$output"
    fi
}

function check_ibmartifactory(){
    output=""
    echo -e "\nChecking connectivity to IBM Artifactory servere" | tee -a ${OUTPUT}
    ansible-playbook -i hosts_openshift -l ${hosts} playbook/ibmregistry_check.yml > ${ANSIBLEOUT}

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "WARNING: cp.icr.io is not reachable. Enabling proxy might fix this issue." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        WARNING=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_redhatartifactory(){
    output=""
    echo -e "\nChecking connectivity to RedHat Artifactory servere" | tee -a ${OUTPUT}
    ansible-playbook -i hosts_openshift -l ${hosts} playbook/redhatregistry_check.yml > ${ANSIBLEOUT}

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "WARNING: registry.redhat.io is not reachable. Enabling proxy might fix this issue." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        WARNING=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_fix_clocksync(){
    output=""
    #if [[ ${FIX} -eq 1 ]]; then
    #    echo -e "\nFixing timesync status" | tee -a ${OUTPUT}
    #    ansible-playbook -i hosts_openshift -l ${hosts} playbook/clocksync_fix.yml > ${ANSIBLEOUT}
    #else
    echo -e "\nChecking timesync status" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${hosts} playbook_311/clocksync_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${hosts} playbook_43/clocksync_check.yml > ${ANSIBLEOUT}
    fi
    
#    fi

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: System clock is currently not synchronised, use ntpd or chrony to sync time" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_kernel_vm(){
    output=""
    echo -e "\nChecking kernel virtual memory on compute nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/kern_vm_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/kern_vm_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Kernel virtual memory on compute nodes should be set to at least 262144. Please update the vm.max_map_count parameter in /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        WARNING=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi

}

function check_message_limit(){
    output=""
    echo -e "\nChecking message limits on compute nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_msg_size_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_msg_size_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Maximum allowable size of messages in bytes should be set to at least 65536. Please update the kernel.msgmax parameter in /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
	ERR=1
	printout "$result"
    fi

    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_queue_size_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_queue_size_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Maximum allowable size of message queue in bytes should be set to at least 65536. Please update the kernel.msgmnb parameter in /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
	ERR=1
	printout "$result"
    fi

    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_num_queue_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_num_queue_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Maximum number of queue identifiers should be set to at least 32768. Please update the kernel.msgmni parameter in /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
	ERR=1
	printout "$result"
    fi

    if [[ ${ERR} -eq 0 ]]; then
        log "[Passed]" result
    fi


    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 && ${ERR} -eq 0 ]]; then
        printout "$output"
    fi

}

function check_shm_limit(){
    output=""
    echo -e "\nChecking shared memory limits on compute nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/tot_page_shm_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/tot_page_shm_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: kernel.shmall should be set to at least 33554432. Please update /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
	ERR=1
	printout "$result"
    fi

    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_shm_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_shm_check.yml > ${ANSIBLEOUT}
    fi

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: kernel.shmmax should be set to at least 68719476736. Please update /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
	ERR=1
	printout "$result"
    fi

    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_num_shm_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_num_shm_check.yml > ${ANSIBLEOUT}
    fi

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: kernel.shmmni should be set to at least 16384. Please update /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
	ERR=1
	printout "$result"
    fi

    if [[ ${ERR} -eq 0 ]]; then
        log "[Passed]" result
    fi

    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 && ${ERR} -eq 0 ]]; then
        printout "$output"
    fi

}

function check_disk_encryption() {
    output=""
    echo -e "\nChecking Disk Encryption. Note: This test is being tested on all core nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${core} playbook_311/disk_encryption_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${core} playbook_43/disk_encryption_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "WARNING: LUKS Encryption is not enabled." result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        WARNING=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi

}

function check_sem_limit() {
    output=""
    echo -e "\nChecking kernel semaphore limit on compute nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/kern_sem_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/kern_sem_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: kernel.sem values must be at least 250 1024000 100 16384. Please update /etc/sysctl.conf" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_max_files(){
    output=""
    echo -e "\nChecking maximum number of open files on compute nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_files_compute_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_files_compute_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Maximum number of open files should be at least 66560. Please update /etc/sysconfig/docker" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_max_process(){
    output=""
    echo -e "\nChecking maximum number of processes on compute nodes" | tee -a ${OUTPUT}
    
    if [[ ${OCP_311} -eq 1 ]] ; then
    	ansible-playbook -i hosts_openshift -l ${compute} playbook_311/max_process_compute_check.yml > ${ANSIBLEOUT}
    else 
	ansible-playbook -i hosts_openshift -l ${compute} playbook_43/max_process_compute_check.yml > ${ANSIBLEOUT}
    fi
    

    if [[ `egrep 'unreachable=[1-9]|failed=[1-9]' ${ANSIBLEOUT}` ]]; then
        log "ERROR: Maximum number of processes should be at least 12288. Please update /etc/sysconfig/docker" result
        cat ${ANSIBLEOUT} >> ${OUTPUT}
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_scc_anyuid(){
    output=""
    echo -e "\nChecking that no user group is defined under scc anyuid" | tee -a ${OUTPUT}
    scc_anyuid=$(oc describe scc anyuid | grep -e system:authenticated -e system:serviceaccounts)
    echo "${scc_anyuid}"
    scc_line_count=$(oc describe scc anyuid | grep -e system:authenticated -e system:serviceaccounts | wc -l)

    if [[ ${scc_line_count} -gt 0 ]]; then
        log "ERROR: system:authenticated and/or system:serviceaccounts should not be in scc anyuid. Run oc edit scc anyuid to update" result
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_cluster_admin(){
    output=""
    echo -e "\nChecking for cluster-admin account" | tee -a ${OUTPUT}
    cluster_admin=$(oc get clusterrolebindings/cluster-admin)
    echo "${cluster_admin}"
    exists=$(oc get clusterrolebindings/cluster-admin | egrep 'not found')

    if [[ ${exists} ]]; then
        log "ERROR: cluster-admin role not assigned. Ask cluster-admin for binding." result
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_admin_role(){
    output=""
    echo -e "\nChecking for admin role" | tee -a ${OUTPUT}
    whoami=$(oc whoami)
    echo "whoami = ${whoami}"
    exists=$(oc get rolebindings admin | egrep '${whoami}')
    echo "${exists}"

    if [[ ${exists} == "" ]]; then
        log "ERROR: output of oc whoami does not exist in oc get rolebindings admin. Ask cluster-admin for binding." result
        ERROR=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_installer_ver(){
    output=""
    echo -e "\nChecking installer version" | tee -a ${OUTPUT}
    OS=$(uname)
    OS=${OS,}
    echo -e "Your os is ${OS}."

    FS=$(df . --output=target | grep -A 1 'Mounted' | grep -v 'Mounted')

    find_ver=$(find ${FS} -name cpd-${OS} -execdir {} version \;)

    install_ver=($(echo "${find_ver}" | grep -Eo '([0-9]{1,}\.)+[0-9]{1,}'))
    multiple_check=$(echo "${find_ver}" | wc -l)
    echo -e ""
    install_build=($(echo "${find_ver}" | grep -Eo '[0-9]*$'))


    if [[ ${multiple_check} -gt 1 ]]; then
	log "WARNING: Multiple installer files found. Recommended that only one file exist on machine for this test to work properly." result
        WARNING=1
	files=($(find ${FS} -name cpd-${OS}))
	
	for ((i=0; i < ${#files[@]} ; i++))
	do
	   echo -e "File: ${files[i]} Version: ${install_ver[i]} Build: ${install_build[i]}"
	done
	
	echo -e ""
        printout "$result"
	log "NOTE: Using ${files[0]} for this check" result
	printout "$result"

	if [[ ${install_ver[0]} != ${GLOBAL[1]} ]]; then
            log "ERROR: Installer version must be 3.0.1, current version is ${install_ver[0]}" result
            ER=1
            printout "$result"
        fi
	
        if [[ ${install_build[0]} -lt ${GLOBAL[2]} && ${ER} -eq 0 ]]; then
            log "ERROR: Installer build must be greater than or equal to 16" result
            ER=1
            printout "$result"
        fi
    else
	echo -e "Installer version is ${install_ver[0]}.
Build is ${install_build[0]}"

	if [[ ${install_ver[0]} != ${GLOBAL[1]} ]]; then
        log "ERROR: Installer version must be 3.0.1, current version is ${install_ver[0]}" result
        ER=1
        printout "$result"
        fi

        if [[ ${install_build[0]} -lt ${GLOBAL[2]} && ${ER} -eq 0 ]]; then
            log "ERROR: Installer build must be greater than or equal to 16" result
            ER=1
            printout "$result"
        fi
    fi

    if [[ ${ER} -eq 0 ]]; then
	log "[Passed]" result
    else
	ERROR=1
    fi

#    if 

    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 && ${ER} -eq 0 ]]; then
        printout "$output"
    fi
    
}

function check_fips_enabled(){
    output=""
    echo -e "\nChecking if FIPS enabled" | tee -a ${OUTPUT}
    fips=$(cat /proc/sys/crypto/fips_enabled)
    echo "${fips}"

    if [[ ${fips} -eq 1 ]]; then
        log "WARNING: FIPS is enabled." result
        WARNING=1
    else
        log "[Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}


#BEGIN CHECK
PRE=0
POST=0
PRE_CPD=0
OCP_311=0

if [[ $# -lt 1 ]]; then
    usage
    exit 1
else
    for var in "$@"
	do
	case $var in

	    --phase=*)
		CHECKTYPE="${var#*=}"
                shift
                if [[ "$CHECKTYPE" = "pre_ocp" ]]; then
                    PRE=1
                elif [[ "$CHECKTYPE" = "post_ocp" ]]; then
                    POST=1
		elif [[ "$CHECKTYPE" = "pre_cpd" ]]; then
		    PRE_CPD=1
                else
                    echo "please only specify check type pre_ocp/post_ocp/pre_cpd"
                    exit 1
                fi            
                ;;

            --host_type=*)
		HOSTTYPE="${var#*=}"
		shift
		hosts=${HOSTTYPE}
		;;

	    --ocp_ver=*)
                VERTYPE="${var#*=}"
		shift
		if [[ "$VERTYPE" = "311" ]]; then
                    OCP_311=1
		else
		    echo "please only specify 311. Note that if you know that your
		    OCP version is 4.3.x, then this option is unnecessary."
		fi
		;;

	    *)
                echo "Sorry the argument is invalid"
                usage
                exit 1
                ;;

	esac
	done
fi

if [[ ${PRE} -eq 1 ]]; then
    validate_internet_connectivity
    validate_ips
    validate_network_speed
    check_subnet
    check_dnsconfiguration
    check_processor
    check_dnsresolve
    check_gateway
    check_hostname
    check_disklatency
    check_diskthroughput
    check_dockerdir_type
    check_unblocked_urls
elif [[ ${POST} -eq 1 ]]; then
    check_openshift_version
    check_fix_clocksync
    check_processor
    check_dnsresolve
    check_timeout_settings
    check_crio_version
    check_disk_encryption
    check_max_files
    check_max_process
elif [[ ${PRE_CPD} -eq 1 ]]; then
    check_kernel_vm
    check_message_limit
    check_shm_limit
    check_sem_limit
    check_scc_anyuid
    check_cluster_admin
    check_admin_role
    check_installer_ver
    check_fips_enabled
fi

if [[ ${ERROR} -eq 1 ]]; then
    echo -e "\nFinished with ERROR, please check ${OUTPUT}"
    exit 2
elif [[ ${WARNING} -eq 1 ]]; then
    echo -e "\nFinished with WARNING, please check ${OUTPUT}"
    exit 1
else
    echo -e "\nFinished successfully! This node meets the requirement" | tee -a ${OUTPUT}
    exit 0
fi
