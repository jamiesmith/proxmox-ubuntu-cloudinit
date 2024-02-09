#!/bin/bash

WORKER_NODE_RAM=32768
WORKER_NODE_DISK=256G
WORKER_NODE_CORES=8

CONTROL_NODE_RAM=8192
CONTROL_NODE_DISK=64G
CONTROL_NODE_CORES=4

case $(hostname) in
    kirk)
        CONTROL_IP=192.168.100.200
        WORKER_IP=192.168.100.201
        ;;
    spock)
        CONTROL_IP=192.168.100.210
        WORKER_IP=192.168.100.211
        ;;
    bones)
        CONTROL_IP=192.168.100.220
        WORKER_IP=192.168.100.221
        ;;
esac
    
# create the controller
#
./clone-cloud-template.sh -c ${CONTROL_NODE_CORES} -m ${CONTROL_NODE_RAM} -d ${CONTROL_NODE_DISK} -i ${CONTROL_IP} k3s-control-$(hostname)
./clone-cloud-template.sh -c ${WORKER_NODE_CORES} -m ${WORKER_NODE_RAM} -d ${WORKER_NODE_DISK} -i ${WORKER_IP} k3s-worker-$(hostname)

echo ${CONTROL_IP} k3s-control-$(hostname)
echo ${WORKER_IP} k3s-worker-$(hostname)