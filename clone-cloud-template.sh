#!/bin/bash

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

qm clone $CLOUD_INIT_VM_ID $vmid --name $vm_hostname --full --storage local-zfs
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

echo "You can now use $vm_hostname"
echo "ssh -o StrictHostKeyChecking=no -i "$CLOUD_INIT_PRIVATE_KEY_FILE" ${CLOUD_INIT_USERNAME}@${vm_hostname}"
