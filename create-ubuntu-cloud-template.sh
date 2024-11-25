#!/bin/bash

# curl -s "https://raw.githubusercontent.com/jamiesmith/proxmox-ubuntu-cloudinit/main/create-ubuntu-cloud-template.sh?$(date +%s)" | /bin/bash -s

# qm stop 9000 --skiplock && qm destroy 9000 --destroy-unreferenced-disks --purge

if [[ ! -f .cloudimage.env ]]
then
    echo 'CLOUD_INIT_USERNAME=${CLOUD_INIT_USERNAME:-anvil}' > .cloudimage.env
    echo 'CLOUD_INIT_PASSWORD=${CLOUD_INIT_PASSWORD:-super_password}' >> .cloudimage.env
    echo 'CLOUD_INIT_PUBLIC_KEY=$(cat ~/.ssh/id_rsa_cloudinit.pub)' >> .cloudimage.env
    echo 'CLOUD_INIT_PRIVATE_KEY_FILE=~/.ssh/id_rsa_cloudinit' >> .cloudimage.env
    echo 'CLOUD_INIT_VM_ID=${CLOUD_INIT_VM_ID:-9000}' >> .cloudimage.env
    echo 'VM_STORAGE=${VM_STORAGE:-local-zfs}' >> .cloudimage.env
    echo 'VM_NAME=${VM_NAME:-ubuntu-server-24.04-template}' >> .cloudimage.env
    echo 'VM_TIMEZONE=$(cat /etc/timezone)' >> .cloudimage.env
    echo 'VM_SNIPPET_PATH=${VM_SNIPPET_PATH:-/var/lib/vz/snippets}' >> .cloudimage.env
    echo 'VM_SNIPPET_LOCATION=${VM_SNIPPET_LOCATION:-local}' >> .cloudimage.env
    echo 'GITHUB_PUBLIC_KEY_USERNAME=' >> .cloudimage.env

    echo "please edit the .cloudimage.env file and then rerun the same command to create the template VM"
    echo "DON'T FORGET TO CHANGE THE PASSWORD"
    exit 1
fi

echo "checking for installed dependencies..."
apt-get install -y jq rig

eval export $(cat .cloudimage.env)

if [ -z "$CLOUD_INIT_USERNAME" ] || [ -z "$CLOUD_INIT_PASSWORD" ] || [ -z "$CLOUD_INIT_PUBLIC_KEY" ]
then
    echo 'one or more required variables are undefined, please check your .cloudimage.env file! Exiting!'
    exit 1
fi

echo "preparing to create $VM_NAME:$CLOUD_INIT_VM_ID with user $CLOUD_INIT_USERNAME stored in $VM_STORAGE"

export TEMPLATE_EXISTS=$(qm list | grep -v grep | grep -ci $CLOUD_INIT_VM_ID)
if [[ $TEMPLATE_EXISTS > 0 ]]
then
    echo "VM $CLOUD_INIT_VM_ID already exists, will delete in 5 seconds... CTRL-C to stop now!"
    secs=6
    while [ $secs -gt 0 ]; do
	echo -ne "\t$secs seconds remaining\033[0K\r"
	sleep 1
	: $((secs--))
    done
    echo ""
    qm stop $CLOUD_INIT_VM_ID --skiplock && qm destroy $CLOUD_INIT_VM_ID --destroy-unreferenced-disks --purge
fi


if [[ ! -f /tmp/noble-server-cloudimg-amd64.img ]]
then
    echo "downloading cloudimg file..."
    curl -s https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img > /tmp/noble-server-cloudimg-amd64.img
fi

mkdir -p /var/lib/vz/snippets/

if [[ -f ./templates/template_cloudinit.yml ]]
then
    echo "loading JRS TEMPLATE cloudinit file..."
    envsubst < ./templates/template_cloudinit.yml > $VM_SNIPPET_PATH/template-user-data.yml
    cat $VM_SNIPPET_PATH/template-user-data.yml
    
else
    echo "downloading template cloudinit file..."
    exit
    curl -s "https://raw.githubusercontent.com/jamiesmith/proxmox-ubuntu-cloudinit/main/templates/template_cloudinit.yml?$(date +%s)" > /tmp/template_cloudinit.yml

    envsubst < /tmp/template_cloudinit.yml > $VM_SNIPPET_PATH/template-user-data.yml
    rm -f /tmp/template_cloudinit.yml
fi

if [[ -f ./templates/clone_cloudinit.yml ]]
then
    echo "loading JRS clone cloudinit file..."
    envsubst < ./templates/clone_cloudinit.yml > $VM_SNIPPET_PATH/clone-user-data.yml

    cat $VM_SNIPPET_PATH/clone-user-data.yml
    
else
    echo "downloading clone cloudinit file..."
    exit
    curl -s "https://raw.githubusercontent.com/jamiesmith/proxmox-ubuntu-cloudinit/main/proxmox/scripts/templates/clone_cloudinit.yml?$(date +%s)" > /tmp/clone_cloudinit.yml
    envsubst < /tmp/clone_cloudinit.yml > $VM_SNIPPET_PATH/clone-user-data.yml

    rm -f /tmp/clone_cloudinit.yml
fi

echo "creating new VM..."
qm create $CLOUD_INIT_VM_ID --memory 2048 --cores 4 --machine q35 --bios ovmf --net0 virtio,bridge=vmbr0,tag=100

echo "importing cloudimg $VM_STORAGE storage..."
qm importdisk $CLOUD_INIT_VM_ID /tmp/noble-server-cloudimg-amd64.img $VM_STORAGE --format qcow2 | grep -v 'transferred'

# finally attach the new disk to the VM as scsi drive
echo "setting vm options..."
qm set $CLOUD_INIT_VM_ID --name "${VM_NAME}"
qm set $CLOUD_INIT_VM_ID --scsihw virtio-scsi-pci
qm set $CLOUD_INIT_VM_ID --scsi0 $(pvesm list $VM_STORAGE | grep "vm-$CLOUD_INIT_VM_ID-disk-0" | awk '{print $1}')
qm set $CLOUD_INIT_VM_ID --scsi1 $VM_STORAGE:cloudinit
qm set $CLOUD_INIT_VM_ID --efidisk0 $VM_STORAGE:0,pre-enrolled-keys=0,efitype=4m,size=528K
qm set $CLOUD_INIT_VM_ID --boot c --bootdisk scsi0 --ostype l26
qm set $CLOUD_INIT_VM_ID --onboot 1
qm resize $CLOUD_INIT_VM_ID scsi0 +4G

qm set $CLOUD_INIT_VM_ID --serial0 socket #--vga serial0
qm set $CLOUD_INIT_VM_ID --ipconfig0 ip=dhcp
qm set $CLOUD_INIT_VM_ID --agent enabled=1,type=virtio,fstrim_cloned_disks=1 --localtime 1

# alternative, but the user-data.yml already has this
# qm set $CLOUD_INIT_VM_ID --sshkey ~/.ssh/id_ed25519.pub
qm set $CLOUD_INIT_VM_ID --cicustom "user=$VM_SNIPPET_LOCATION:snippets/template-user-data.yml" # qm cloudinit dump 9000 user

# enable the line below to generate
# log console output to /tmp/serial.$CLOUD_INIT_VM_ID.log
# useful for debugging cloud-init issues
#qm set $CLOUD_INIT_VM_ID -args "-chardev file,id=char0,mux=on,path=/tmp/serial.$CLOUD_INIT_VM_ID.log,signal=off -serial chardev:char0"
#tail -f /tmp/serial.$CLOUD_INIT_VM_ID.log
#qm terminal $CLOUD_INIT_VM_ID --iface serial0
#qm set $CLOUD_INIT_VM_ID --serial1 socket --vga serial1

echo "starting template vm..."
qm start $CLOUD_INIT_VM_ID

# echo "waiting for template vm boot..."
# secs=75
# while [ $secs -gt 0 ]; do
#    echo -ne "\t$secs seconds remaining\033[0K\r"
#    sleep 1
#    : $((secs--))
# done
# echo ""
echo "waiting for QEMU guest agent to start..."

BOOT_COMPLETE="0"
while [[ "$BOOT_COMPLETE" -ne "1" ]]; do
    sleep 5
    BOOT_COMPLETE=$(qm guest exec $CLOUD_INIT_VM_ID -- /bin/bash -c 'ls /var/lib/cloud/instance/boot-finished | wc -l | tr -d "\n"' | jq -r '."out-data"')
done
echo "Cloud-init of template completed!"

if [ ! -z "$GITHUB_PUBLIC_KEY_USERNAME" ]
then
    echo "importing ssh public keys from Github user $GITHUB_PUBLIC_KEY_USERNAME..."
    qm guest exec $CLOUD_INIT_VM_ID -- /bin/bash -c "ssh-import-id -o /home/$CLOUD_INIT_USERNAME/.ssh/authorized_keys gh:$GITHUB_PUBLIC_KEY_USERNAME "
fi

echo "setting user $CLOUD_INIT_USERNAME password..."
qm guest exec $CLOUD_INIT_VM_ID -- /bin/bash -c "echo \"$CLOUD_INIT_USERNAME:$CLOUD_INIT_PASSWORD\" | chpasswd"

echo "saving log files and cleaning up..."
qm guest exec $CLOUD_INIT_VM_ID -- /bin/bash -c 'cloud-init collect-logs'
qm guest exec $CLOUD_INIT_VM_ID -- /bin/bash -c 'cloud-init clean'

echo "setting cloud-init to use user=$VM_SNIPPET_LOCATION:snippets/clone-user-data.yml..."
qm set $CLOUD_INIT_VM_ID --cicustom "user=$VM_SNIPPET_LOCATION:snippets/clone-user-data.yml"
# qm cloudinit dump 9000 user

echo "shutting down and converting to template VM..."
qm shutdown $CLOUD_INIT_VM_ID
qm stop $CLOUD_INIT_VM_ID
qm template $CLOUD_INIT_VM_ID
echo "Operations Completed!"
