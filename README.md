# proxmox-ubuntu-cloudinit


This is my proxmox cloud init, first iteration, based heavily on https://github.com/traefikturkey/onvoy/tree/main

Files:
- `create-ubuntu-cloud-template.sh` - creates the cloud template
- `clone-cloud-template.sh` - clones the template, 
- `nukeVM.sh` - to stop and delete a vm, which is useful when experimenting
- `sync-to-proxmox.sh` - this is just a shell script so I can use a code editor on my mac
- `templates/` - cloud init files, change these to add additional packages (or remove some that are preinstalled)


You can also bootstrap it by running:
```
curl -s "https://raw.githubusercontent.com/jamiesmith/proxmox-ubuntu-cloudinit/main/create-ubuntu-cloud-template.sh?$(date +%s)" | /bin/bash -s
```