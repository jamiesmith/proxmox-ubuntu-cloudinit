#!/bin/bash
# Simple script to push changes to proxmox host
#

function die_usage
{
    echo "Usage: $0 user@host:/path/to/dest"
    echo "$*"
    exit 9
}


if [ $# -ne 1 ]
then
  die_usage "Missing destination"  
fi

while [ 1 ]
do
rsync --archive \
    --verbose \
    --compress \
    -e ssh \
    ./ "$@"
sleep 1
done