#!/bin/bash
# Simple script to push changes to proxmox host
#

function die_usage
{
    echo "Usage: $0 user@host:/path/to/dest"
    echo "$*"
    exit 9
}


hosts="kirk spock bones picard"

for host in $hosts
do
    echo "sync to $host"
    rsync --archive \
	  --verbose \
	  --compress \
	  -e ssh \
	  ./ "${host}:proxmox-ubuntu-cloudinit"
done

