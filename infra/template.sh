#!/bin/bash
set -euo pipefail

# -------------------------------------------------
# Configuration
# -------------------------------------------------
VMID=9000
VM_NAME="ubuntu-docker-template"
USERNAME="ubuntu"
SSH_HOST_KEY="${HOME}/.ssh/proxmox_host"
SSH_KEY="${HOME}/.ssh/it-machine.pub"
SSH_KEY_PRIV="${HOME}/.ssh/it-machine"
IMG_LOCAL="./img/jammy-server-cloudimg-amd64.img"
IMG_NAME="jammy-server-cloudimg-amd64.img"
STORAGE="local-lvm"
BRIDGE="vmbr0"
MEMORY=2048
CORES=2
DISK_SIZE="10G"
STATIC_IP="192.168.123.20"
GATEWAY="192.168.123.2"
NAMESERVER="8.8.8.8 1.1.1.1"

PROXMOX_HOST="192.168.123.130"
PROXMOX_USER="root"

# -------------------------------------------------
# Helpers
# -------------------------------------------------
ssh_proxmox() {
  ssh -i "${SSH_HOST_KEY}"  -o StrictHostKeyChecking=accept-new "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
}

echo "==> Checking if template ${VMID} already exists..."
if ssh_proxmox "qm config ${VMID} &>/dev/null"; then
  echo "Template/VM ${VMID} already exists. Checking if it is a template..."
  if ssh_proxmox "qm config ${VMID} | grep -q 'template: 1'"; then
    echo "✓ Template ${VMID} already exists. Nothing to do."
    ssh_proxmox "qm set ${VMID} --ciupgrade 0"

    exit 0
  else
    echo "VM ${VMID} exists but is not a template. Stopping and converting..."
    ssh_proxmox "qm shutdown ${VMID} || true"
    ssh_proxmox "while qm status ${VMID} | grep -q running; do sleep 2; done"
    ssh_proxmox "qm template ${VMID}"
    ssh_proxmox "qm set ${VMID} --ciupgrade 0"

    echo "✓ Converted existing VM to template."
    exit 0
  fi
fi

# -------------------------------------------------
# 1. Upload image if needed
# -------------------------------------------------
echo "==> Checking if image exists on Proxmox..."
if ! ssh_proxmox "ls /var/lib/vz/template/iso/${IMG_NAME} &>/dev/null"; then
  echo "Uploading image to Proxmox..."
  scp -i "${SSH_HOST_KEY}" "${IMG_LOCAL}" "${PROXMOX_USER}@${PROXMOX_HOST}:/var/lib/vz/template/iso/${IMG_NAME}"
else
  echo "✓ Image already present on Proxmox."
fi

# -------------------------------------------------
# 2. Create the VM
# -------------------------------------------------
echo "==> Creating VM ${VMID}..."
ssh_proxmox "qm create ${VMID} \
  --name ${VM_NAME} \
  --memory ${MEMORY} \
  --cores ${CORES} \
  --net0 virtio,bridge=${BRIDGE} \
  --scsihw virtio-scsi-pci \
  --agent enabled=1 \
  --serial0 socket \
  --vga serial0"

echo "==> Importing disk..."
ssh_proxmox "qm importdisk ${VMID} /var/lib/vz/template/iso/${IMG_NAME} ${STORAGE}"

echo "==> Attaching and resizing disk..."
ssh_proxmox "qm set ${VMID} --scsi0 ${STORAGE}:vm-${VMID}-disk-0"
ssh_proxmox "qm resize ${VMID} scsi0 ${DISK_SIZE}"

echo "==> Configuring cloud-init..."

# Copy the public key to Proxmox temporarily
scp -i "${SSH_HOST_KEY}" -o StrictHostKeyChecking=accept-new \
  "${SSH_KEY}" "${PROXMOX_USER}@${PROXMOX_HOST}:/tmp/sshkey.pub"

# Set cloud-init using the file
ssh_proxmox "qm set ${VMID} \
  --ide2 ${STORAGE}:cloudinit \
  --boot order=scsi0 \
  --ciuser ${USERNAME} \
  --sshkey /tmp/sshkey.pub"

# Clean up
ssh_proxmox "rm -f /tmp/sshkey.pub"

# Set network
ssh_proxmox "qm set ${VMID} \
  --ipconfig0 ip=${STATIC_IP}/24,gw=${GATEWAY} \
  --nameserver '${NAMESERVER}'"





# -------------------------------------------------
# 3. Start and wait for SSH
# -------------------------------------------------
echo "==> Starting VM..."
ssh_proxmox "qm start ${VMID}"

echo "==> Waiting for SSH to become available on ${STATIC_IP}..."
for i in {1..60}; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "${SSH_KEY%.*}" \
       "${USERNAME}@${STATIC_IP}" "echo SSH ready" &>/dev/null; then
    echo "✓ SSH is ready."
    break
  fi
  echo "  Attempt $i/60..."
  sleep 5
done

# Final check
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "${SSH_KEY%.*}" \
     "${USERNAME}@${STATIC_IP}" "echo ok" &>/dev/null; then
  echo "ERROR: SSH never became ready. Check the VM console."
  exit 1
fi

# -------------------------------------------------
# 4. Install Docker + QEMU guest agent + disable auto-updates
# -------------------------------------------------
echo "==> Installing Docker, QEMU guest agent and disabling auto-updates..."
ssh -i "${SSH_KEY_PRIV}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${USERNAME}@${STATIC_IP}" bash <<'EOF'
set -e

# Install qemu-guest-agent + dependencies
sudo apt-get update -y
sudo apt-get install -y qemu-guest-agent curl ca-certificates
sudo systemctl enable --now qemu-guest-agent

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu

# Docker Compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Clean cloud-init so the template is fresh
sudo cloud-init clean --logs

echo "Docker version: $(docker --version)"
echo "Compose version: $(docker compose version)"
EOF

echo "✓ Docker installed and auto-updates disabled."

# -------------------------------------------------
# 5. Convert to template
# -------------------------------------------------
echo "==> Shutting down VM..."
ssh_proxmox "qm shutdown ${VMID}"
ssh_proxmox "while qm status ${VMID} | grep -q running; do sleep 2; done"

echo "==> Converting to template..."
ssh_proxmox "qm template ${VMID}"

echo "✓ Template ${VMID} (${VM_NAME}) is ready."


ssh_proxmox "qm set ${VMID} --ciupgrade 0"
