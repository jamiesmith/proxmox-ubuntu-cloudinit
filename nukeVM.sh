#!/bin/bash

for vmid in $*
do
    qm stop $vmid
    qm destroy $vmid
done
