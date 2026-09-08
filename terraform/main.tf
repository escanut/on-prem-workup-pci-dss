resource "proxmox_virtual_environment_file" "ubuntu_cloud_image" {
  content_type = "iso"                       # or "import"
  datastore_id = "local"                     # storage on Proxmox that accepts ISO/import
  node_name    = var.proxmox_node

  source_file {
  path      = "./img/jammy-server-cloudimg-amd64.img"
  file_name = "jammy-server-cloudimg-amd64.img"
  }
}


resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.proxmox_node

  source_raw {
    data = <<-EOF
    #cloud-config
    package_update: true
    package_upgrade: true

    packages:
      - qemu-guest-agent
      - apt-transport-https
      - ca-certificates
      - curl
      - gnupg
      - lsb-release

    runcmd:
      # Enable QEMU Guest Agent
      - systemctl enable --now qemu-guest-agent

      # Install Docker
      - curl -fsSL https://get.docker.com | sh
      - systemctl enable --now docker
      - usermod -aG docker ubuntu

      # Install Docker Compose plugin (v2)
      - mkdir -p /usr/local/lib/docker/cli-plugins
      - curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
      - chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

      # Optional: make sure docker works without sudo for ubuntu user
      - newgrp docker || true
    EOF

    file_name = "ubuntu-base-docker.yaml"
  }
}

# Template vm
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  name        = var.vm_name
  node_name   = var.proxmox_node
  vm_id       = 9000
  description = "Managed by Terraform"
  tags        = ["terraform", "ubuntu"]

  template        = true
  started         = false
  stop_on_destroy = true                 

  # QEMU Guest Agent (recommended)
  agent {
    enabled = true
    timeout = "25m"
  }

  cpu {
    cores = 2
    type  = "host" 
  }

  memory {
    dedicated = 2048
  }
  
  scsi_hardware = "virtio-scsi-pci" 
 # Disk from the downloaded cloud image
  disk {
    datastore_id = var.datastore_id
    file_id      = proxmox_virtual_environment_file.ubuntu_cloud_image.id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 10
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }

  # Cloud-init configuration
  initialization {

    user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
   
    dynamic "ip_config" {
      for_each = var.ip_config != null ? [1] : []
      content {
        ipv4 {
          address = var.ip_config.address
          gateway = var.ip_config.gateway
        }
      }
    }

    # Fallback to DHCP if no static IP is given
    dynamic "ip_config" {
      for_each = var.ip_config == null ? [1] : []
      content {
        ipv4 {
          address = "dhcp"
        }
      }
    }

    user_account {
      username = "ubuntu"
      keys     = [
        file("~/.ssh/it-machine.pub")     # change path if needed
      ]
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    
  }
}

# Initial frontend vm
resource "proxmox_virtual_environment_vm" "frontend" {
  name      = "workup-frontend"
  node_name = var.proxmox_node

  description = "Frontend segment (nginx)"
  tags        = ["workup", "frontend"]

  started         = true
  stop_on_destroy = true

  # Clone from the template
  clone {
    vm_id = proxmox_virtual_environment_vm.ubuntu_template.vm_id
    full  = true                     # full clone (recommended)
  }

  agent {
    enabled = true
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048                 
  }

  # You can override disk size if needed
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = 20
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Cloud-init for this specific VM (IP, hostname, etc.)
  initialization {
    user_account {
      username = "ubuntu"
      keys     = [file("~/.ssh/it-machine.pub")]
    }

    ip_config {
      ipv4 {
        address = "192.168.123.21/24"
        gateway = "192.168.123.2"
      }
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
  }
}