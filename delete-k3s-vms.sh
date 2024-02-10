#!/bin/bash

for vmid in $(qm list | grep k3s | awk '{print $1}')
do
    qm stop $vmid
    qm destroy $vmid    
done