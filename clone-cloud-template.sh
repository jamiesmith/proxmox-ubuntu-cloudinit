#!/bin/bash

function die_usage
{
    echo "Usage: $0 [-d disk] [-m memory] [name]"
    echo " -c cores"
    echo " -d disk (like, 10G)"
    echo " -m memory (bytes)"
    echo "$*"
    exit 9
}
MEMORY=2048
DISK=10G
CORES=4
IP_ADDR=""

while getopts "c:d:i:m:" option
do
    case $option in
    c)
        CORES=$OPTARG
        ;;
    d)
        DISK=$OPTARG
        ;;
    i)
        IP_ADDR=$OPTARG
        ;;
    m)
        MEMORY=$OPTARG
        ;;
	*)
	    die_usage "Wrong arg $option"
        
    esac
done
shift `expr $OPTIND - 1`

vmid=$(pvesh get /cluster/nextid)

eval export $(cat .cloudimage.env)

if [ $# -gt 0 ]
then
    vm_hostname="$1"
else
    vm_hostname=$(rig | head -1 | tr " " "-"| tr '[:upper:]' '[:lower:]')
fi


# [ $vmid = 1 ] && vmid=100
echo "creating [$vm_hostname] ($vmid)"

qm clone $CLOUD_INIT_VM_ID $vmid --name $vm_hostname --full --storage ${VM_STORAGE}
qm resize $vmid scsi0 +"${DISK}"
qm set $vmid --memory "${MEMORY}" --cores "${CORES}"

SSH_HOST=$vm_hostname
if [ -n "$IP_ADDR" ]
then
    echo "Setting the IP to gw=192.168.1.1,ip=$IP_ADDR"
    qm set $vmid --ipconfig0 gw=192.168.100.1,ip=${IP_ADDR}/24 --nameserver 192.168.1.80
    SSH_HOST=$IP_ADDR
fi

qm start $vmid

echo "Started $vm_hostname ($vmid)"

BOOT_COMPLETE="0"
while [[ "$BOOT_COMPLETE" -ne "1" ]]; do
    echo "waiting for QEMU guest agent to start..."
    sleep 5
    BOOT_COMPLETE=$(qm guest exec $vmid -- /bin/bash -c 'ls /var/lib/cloud/instance/boot-finished | wc -l | tr -d "\n"' | jq -r '."out-data"')
done

echo "Cloud-init of template completed, correcting host name and rebooting!"

qm guest exec $vmid -- /bin/bash -c "hostnamectl set-hostname $vm_hostname"
qm guest exec $vmid -- /bin/bash -c "reboot"
sleep 60
BOOT_COMPLETE=0
while [[ "$BOOT_COMPLETE" -ne "1" ]]; do
    echo "waiting for QEMU guest agent to start..."
    sleep 5
    BOOT_COMPLETE=$(qm guest exec $vmid -- /bin/bash -c 'ls /var/lib/cloud/instance/boot-finished | wc -l | tr -d "\n"' | jq -r '."out-data"')
done

echo "You can now use $SSH_HOST ($vmid)"
echo "ssh -o StrictHostKeyChecking=no -i "$CLOUD_INIT_PRIVATE_KEY_FILE" ${CLOUD_INIT_USERNAME}@${SSH_HOST}"
