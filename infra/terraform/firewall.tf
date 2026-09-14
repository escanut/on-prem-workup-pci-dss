

resource "proxmox_virtual_environment_firewall_ipset" "management" {
  name    = "management"
  comment = "Admin workstations / jump hosts - managed by Terraform"

  cidr {
    name    = "192.168.123.132/32" # my specific dev vm
    comment = "Lab / management network"
  }
 
}

# DATACENTER FIREWALL

resource "proxmox_virtual_environment_cluster_firewall" "cluster" {
  enabled        = true
  ebtables       = true
  input_policy   = "DROP"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"


  log_ratelimit {
    enabled = true
    burst = 5
    rate = "1/second"
    
  }
}

resource "proxmox_virtual_environment_firewall_rules" "cluster_mgmt" {
  # leave node_name / vm_id empty → cluster level

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Proxmox GUI from management"
    source  = "+management"          # references the IPSet
    dport   = "8006"
    proto   = "tcp"
    log     = "nolog"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH from management"
    source  = "+management"
    dport   = "22"
    proto   = "tcp"
    log     = "nolog"
  }

  # Extra for ping tests
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "ICMP from management"
    source  = "+management"
    proto   = "icmp"
  }
}


# NODE FIREWALL

resource "proxmox_node_firewall" "node" {
  node_name = var.proxmox_node          

  enabled             = true
  log_level_in        = "nolog"         
  log_level_out       = "nolog"
  log_level_forward   = "nolog"
  ndp                 = true
  nosmurfs            = true
}

resource "proxmox_virtual_environment_firewall_rules" "node_mgmt" {
  node_name = var.proxmox_node

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "GUI from management (host)"
    source  = "+management"
    dport   = "8006"
    proto   = "tcp"
    iface   = "vmbr0"                   
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH from management (host)"
    source  = "+management"
    dport   = "22"
    proto   = "tcp"
    iface   = "vmbr0"
  }

  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "ICMP from management"
    source  = "+management"
    proto   = "icmp"
    iface = "vmbr0"
  }
}

# VM FIREWALL

# Security groups for reuseability
resource "proxmox_virtual_environment_cluster_firewall_security_group" "mgmt_ssh" {
  name    = "mgmt-ssh"
  comment = "Allow SSH from management network"

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "+management"
    dport   = "22"
    proto   = "tcp"
    comment = "SSH"
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "mgmt_icmp" {
  name    = "mgmt-icmp"
  comment = "Allow ICMP from management network"

  rule {
    type    = "in"
    action  = "ACCEPT"
    source  = "+management"
    proto   = "icmp"
    comment = "ICMP"
  }
}

# Enable firewall on all vms
resource "proxmox_virtual_environment_firewall_options" "frontend" {
  node_name     = proxmox_virtual_environment_vm.frontend.node_name
  vm_id         = proxmox_virtual_environment_vm.frontend.vm_id
  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_options" "auth" {
  node_name     = proxmox_virtual_environment_vm.auth.node_name
  vm_id         = proxmox_virtual_environment_vm.auth.vm_id
  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_options" "backend" {
  node_name     = proxmox_virtual_environment_vm.backend.node_name
  vm_id         = proxmox_virtual_environment_vm.backend.vm_id
  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

resource "proxmox_virtual_environment_firewall_options" "observability" {
  node_name     = proxmox_virtual_environment_vm.observability.node_name
  vm_id         = proxmox_virtual_environment_vm.observability.vm_id
  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
}

# Attach security groups to vms 
resource "proxmox_virtual_environment_firewall_rules" "frontend" {
  node_name = proxmox_virtual_environment_vm.frontend.node_name
  vm_id     = proxmox_virtual_environment_vm.frontend.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_ssh.name
    iface          = "net0"
    comment        = "SSH from management"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_icmp.name
    iface          = "net0"
    comment        = "ICMP from management"
  }
}

resource "proxmox_virtual_environment_firewall_rules" "auth" {
  node_name = proxmox_virtual_environment_vm.auth.node_name
  vm_id     = proxmox_virtual_environment_vm.auth.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_ssh.name
    iface          = "net0"
    comment        = "SSH from management"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_icmp.name
    iface          = "net0"
    comment        = "ICMP from management"
  }
}

resource "proxmox_virtual_environment_firewall_rules" "backend" {
  node_name = proxmox_virtual_environment_vm.backend.node_name
  vm_id     = proxmox_virtual_environment_vm.backend.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_ssh.name
    iface          = "net0"
    comment        = "SSH from management"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_icmp.name
    iface          = "net0"
    comment        = "ICMP from management"
  }
}

resource "proxmox_virtual_environment_firewall_rules" "observability" {
  node_name = proxmox_virtual_environment_vm.observability.node_name
  vm_id     = proxmox_virtual_environment_vm.observability.vm_id

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_ssh.name
    iface          = "net0"
    comment        = "SSH from management"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.mgmt_icmp.name
    iface          = "net0"
    comment        = "ICMP from management"
  }
}