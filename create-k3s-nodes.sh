#!/bin/bash

WORKER_NODE_RAM=32768
WORKER_NODE_DISK=256G
WORKER_NODE_CORES=8

CONTROL_NODE_RAM=8192
CONTROL_NODE_DISK=64G
CONTROL_NODE_CORES=4

hosts="kirk spock bones"

STARTING_IP=200
IP=${STARTING_IP}

BASE_ADDR=192.168.100

# These are per proxmox node
#
CONTROL_NODE_COUNT=1
WORKER_NODE_COUNT=2

HOSTFILE=hosts.tmp
rm -f ${HOSTFILE}

for host in $hosts
do
    count=0
    
    while [ $count -lt $CONTROL_NODE_COUNT ]
    do
        hostname="k3s-${host}-control"
        if [ $CONTROL_NODE_COUNT -gt 1 ]
        then
            hostname="${hostname}-${count}"
        fi
        ssh root@${host} "cd proxmox-ubuntu-cloudinit && ./clone-cloud-template.sh -c ${CONTROL_NODE_CORES} \
            -m ${CONTROL_NODE_RAM} \
            -d ${CONTROL_NODE_DISK} \
            -i ${BASE_ADDR}.${IP} \
            ${hostname}"
        ((count+=1))
        echo ${BASE_ADDR}.${IP} ${hostname} >> ${HOSTFILE}
        ((IP+=1))
    done

    count=0
    
    while [ $count -lt $WORKER_NODE_COUNT ]
    do
        hostname="k3s-${host}-worker"
        if [ $WORKER_NODE_COUNT -gt 1 ]
        then
            hostname="${hostname}-${count}"
        fi
        ssh root@${host} "cd proxmox-ubuntu-cloudinit && ./clone-cloud-template.sh -c ${WORKER_NODE_CORES} \
            -m ${WORKER_NODE_RAM} \
            -d ${WORKER_NODE_DISK} \
            -i ${BASE_ADDR}.${IP} \
            ${hostname}"
        ((count+=1))
        echo ${BASE_ADDR}.${IP} ${hostname} >> ${HOSTFILE}
        ((IP+=1))
    done
    ((IP+=5))
done

cat ${HOSTFILE}