#!/bin/bash


VM_IDS=(100 101 102 103 104 105 106 107 108 109 9000)
IMG_NAME="jammy-server-cloudimg-amd64.img"
IMG_PATH="/var/lib/vz/template/iso/${IMG_NAME}"


for vm in "${VM_IDS[@]}"; do
 ssh -i ~/.ssh/proxmox_host root@192.168.123.130 "qm unlock ${vm}" 
 ssh -i ~/.ssh/proxmox_host root@192.168.123.130 "qm stop ${vm}" 
 ssh -i ~/.ssh/proxmox_host root@192.168.123.130 "qm destroy ${vm} --purge" 
done

ssh -i ~/.ssh/proxmox_host root@192.168.123.130 "rm -f ${IMG_PATH}"
