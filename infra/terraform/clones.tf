# Frontend vm
resource "proxmox_virtual_environment_vm" "frontend" {
  name      = "workup-frontend"
  node_name = var.proxmox_node

  description = "Frontend segment (nginx)"
  tags        = ["workup", "frontend"]

  started         = true
  stop_on_destroy = true

  # Clone from the template
  clone {
    vm_id = var.template_id
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
    dedicated = 768            
  }

  # You can override disk size if needed
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = 10
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    firewall = true
  }

  

  # Cloud-init for this specific VM (IP, hostname, etc.)
  initialization {

    
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

# Auth vm
resource "proxmox_virtual_environment_vm" "auth" {
  name      = "workup-auth"
  node_name = var.proxmox_node

  description = "Auth segment (keycloak)"
  tags        = ["workup", "auth"]

  started         = true
  stop_on_destroy = true

  # Clone from the template
  clone {
    vm_id = var.template_id
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
    dedicated = 1536                 
  }

  # You can override disk size if needed
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = 10
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    firewall = true
  }

  # Cloud-init for this specific VM (IP, hostname, etc.)
  initialization {

    
    ip_config {
      
      ipv4 {
        address = "192.168.123.22/24"
        gateway = "192.168.123.2"
      }
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
  }
}

# backend vm
resource "proxmox_virtual_environment_vm" "backend" {
  name      = "workup-backend"
  node_name = var.proxmox_node

  description = "backend segment (golang)"
  tags        = ["workup", "backend"]

  started         = true
  stop_on_destroy = true

  # Clone from the template
  clone {
    vm_id = var.template_id
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
    dedicated = 1024               
  }

  # You can override disk size if needed
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = 10
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    firewall = true
  }

  # Cloud-init for this specific VM (IP, hostname, etc.)
  initialization {

    
    ip_config {
      
      ipv4 {
        address = "192.168.123.23/24"
        gateway = "192.168.123.2"
      }
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
  }
}


# observability vm
resource "proxmox_virtual_environment_vm" "observability" {
  name      = "workup-observability"
  node_name = var.proxmox_node

  description = "observability segment (loki + prometheus + grafana)"
  tags        = ["workup", "observability"]

  started         = true
  stop_on_destroy = true

  # Clone from the template
  clone {
    vm_id = var.template_id
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
    dedicated = 1536                
  }

  # You can override disk size if needed
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = 10
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    firewall = true
  }

  # Cloud-init for this specific VM (IP, hostname, etc.)
  initialization {

    
    ip_config {
      
      ipv4 {
        address = "192.168.123.24/24"
        gateway = "192.168.123.2"
      }
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }
  }
}