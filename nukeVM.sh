#!/bin/bash

for vmid in $*
do
    qm stop $1
    qm destroy $1
done
