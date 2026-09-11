#!/bin/bash

VM_IDS=(100 101 102 103)

for vm in "${VM_IDS[@]}"; do
 ssh -i ~/.ssh/proxmox_host root@192.168.123.130 "qm stop ${vm}" 
 ssh -i ~/.ssh/proxmox_host root@192.168.123.130 "qm destroy ${vm} --purge" 
done