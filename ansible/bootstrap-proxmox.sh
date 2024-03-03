#!/bin/bash

ansible-playbook ./playbooks/proxmox-bootstrap.yml \
		 --inventory ./inventory/hosts.ini \
		 --user root
