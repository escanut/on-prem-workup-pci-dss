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
IMG_DIR="./img"
IMG_LOCAL="${IMG_DIR}/jammy-server-cloudimg-amd64.img"
IMG_NAME="jammy-server-cloudimg-amd64.img"
# Official Ubuntu cloud image (Jammy current)
IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
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
  ssh -i "${SSH_HOST_KEY}" -o StrictHostKeyChecking=accept-new "${PROXMOX_USER}@${PROXMOX_HOST}" "$@"
}

echo "==> Checking if template ${VMID} already exists..."
if ssh_proxmox "qm config ${VMID} &>/dev/null"; then
  echo "Template/VM ${VMID} already exists. Checking if it is a template..."
  if ssh_proxmox "qm config ${VMID} | grep -q 'template: 1'"; then
    echo "Template ${VMID} already exists. Nothing to do."
    ssh_proxmox "qm set ${VMID} --ciupgrade 0"
    exit 0
  else
    echo "VM ${VMID} exists but is not a template. Stopping and converting..."
    ssh_proxmox "qm shutdown ${VMID} || true"
    ssh_proxmox "while qm status ${VMID} | grep -q running; do sleep 2; done"
    ssh_proxmox "qm template ${VMID}"
    ssh_proxmox "qm set ${VMID} --ciupgrade 0"
    echo "Converted existing VM to template."
    exit 0
  fi
fi

# -------------------------------------------------
# 1. Ensure cloud image is on Proxmox
#    Order: already on Proxmox → local file → download then upload
# -------------------------------------------------
echo "==> Checking if image exists on Proxmox..."
if ssh_proxmox "ls /var/lib/vz/template/iso/${IMG_NAME} &>/dev/null"; then
  echo "Image already present on Proxmox."
else
  # Need a local copy to scp
  if [[ ! -f "${IMG_LOCAL}" ]]; then
    echo "Local image not found at ${IMG_LOCAL}"
    echo "==> Downloading ${IMG_NAME} from Ubuntu cloud images..."
    mkdir -p "${IMG_DIR}"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --progress-bar -o "${IMG_LOCAL}.partial" "${IMG_URL}"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "${IMG_LOCAL}.partial" "${IMG_URL}"
    else
      echo "ERROR: neither curl nor wget is available to download the image."
      exit 1
    fi
    mv "${IMG_LOCAL}.partial" "${IMG_LOCAL}"
    echo "Downloaded to ${IMG_LOCAL}"
  else
    echo "Local image found at ${IMG_LOCAL}"
  fi

  echo "Uploading image to Proxmox..."
  scp -i "${SSH_HOST_KEY}" -o StrictHostKeyChecking=accept-new \
    "${IMG_LOCAL}" "${PROXMOX_USER}@${PROXMOX_HOST}:/var/lib/vz/template/iso/${IMG_NAME}"
  echo "Upload complete."
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
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "${SSH_KEY_PRIV}" \
       "${USERNAME}@${STATIC_IP}" "echo SSH ready" &>/dev/null; then
    echo "SSH is ready."
    break
  fi
  echo "  Attempt $i/60..."
  sleep 5
done

# Final check
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "${SSH_KEY_PRIV}" \
     "${USERNAME}@${STATIC_IP}" "echo ok" &>/dev/null; then
  echo "ERROR: SSH never became ready. Check the VM console."
  exit 1
fi

# -------------------------------------------------
# 4. Install Docker + QEMU guest agent + disable auto-updates
# -------------------------------------------------
echo "==> Installing Docker, QEMU guest agent..."
ssh -i "${SSH_KEY_PRIV}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${USERNAME}@${STATIC_IP}" bash <<'EOF'
set -euo pipefail

# ---------------------------------------------------------------
# Root cause (Canonical bug LP#1693361, cloud-init upstream issue,
# reproduced across Packer/Vagrant/Proxmox builds): apt-daily.timer
# and apt-daily-upgrade.timer have Persistent=true, so on a fresh
# cloud image they fire unattended-upgrades immediately on first
# boot and re-fire on a schedule, holding
# /var/lib/dpkg/lock-frontend indefinitely. A fuser-based polling
# loop never finds a clean window because the lock keeps getting
# re-acquired. Fix: kill and mask the units before touching apt at
# all, so the lock is never taken in the first place. Do this once,
# in the template, so every clone inherits it.
# ---------------------------------------------------------------
echo "Disabling apt-daily / unattended-upgrades to remove the lock race..."
sudo systemctl stop apt-daily.service apt-daily-upgrade.service \
  apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service 2>/dev/null || true
sudo systemctl kill --kill-who=all apt-daily.service 2>/dev/null || true
sudo systemctl kill --kill-who=all apt-daily-upgrade.service 2>/dev/null || true
sudo systemctl mask apt-daily.service apt-daily-upgrade.service \
  apt-daily.timer apt-daily-upgrade.timer unattended-upgrades.service

# Wait out cloud-init's own bootstrap (this part is legitimate and fast)
sudo cloud-init status --wait 2>/dev/null || true

# Belt-and-braces: if anything still holds the lock (e.g. a dpkg
# post-install trigger from cloud-init itself), let apt's own
# lock-timeout option wait for it instead of a custom fuser poll.
# -o DPkg::Lock::Timeout is a real apt option (apt.conf(5)); it makes
# apt retry acquiring the lock for N seconds instead of failing
# immediately with "Could not get lock".
apt_retry() {
  local n=1 max=5
  while true; do
    if sudo DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 "$@"; then
      return 0
    fi
    if [ "$n" -ge "$max" ]; then
      echo "ERROR: apt-get $* failed after $max attempts"
      return 1
    fi
    echo "apt-get failed (attempt $n/$max); retrying in 15s..."
    n=$((n + 1))
    sleep 15
  done
}

apt_retry update -y
apt_retry install -y qemu-guest-agent curl ca-certificates
sudo systemctl enable --now qemu-guest-agent

# Install Docker (get.docker.com handles its own apt usage)
curl -fsSL https://get.docker.com | sudo sh
sudo systemctl enable --now docker
sudo usermod -aG docker ubuntu

# Docker Compose plugin
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Clean cloud-init so clones get a fresh first boot
sudo cloud-init clean --logs

echo "Docker version: $(docker --version)"
echo "Compose version: $(docker compose version)"
EOF

echo "Docker installed."

# -------------------------------------------------
# 5. Convert to template
# -------------------------------------------------
echo "==> Shutting down VM..."
ssh_proxmox "qm shutdown ${VMID}"
ssh_proxmox "while qm status ${VMID} | grep -q running; do sleep 2; done"

echo "==> Converting to template..."
ssh_proxmox "qm template ${VMID}"

echo "Template ${VMID} (${VM_NAME}) is ready."

ssh_proxmox "qm set ${VMID} --ciupgrade 0"