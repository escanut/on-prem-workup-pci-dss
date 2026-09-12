output "vms" {
  value = {
    
    frontend = {
      id   = proxmox_virtual_environment_vm.frontend.vm_id
      ip   = try(proxmox_virtual_environment_vm.frontend.ipv4_addresses[1][0], null)
      name = proxmox_virtual_environment_vm.frontend.name
    }

    auth = {
      id   = proxmox_virtual_environment_vm.auth.vm_id
      ip   = try(proxmox_virtual_environment_vm.auth.ipv4_addresses[1][0], null)
      name = proxmox_virtual_environment_vm.auth.name
    }

    backend = {
      id   = proxmox_virtual_environment_vm.backend.vm_id
      ip   = try(proxmox_virtual_environment_vm.backend.ipv4_addresses[1][0], null)
      name = proxmox_virtual_environment_vm.backend.name
    }
   
    observability = {
      id   = proxmox_virtual_environment_vm.observability.vm_id
      ip   = try(proxmox_virtual_environment_vm.observability.ipv4_addresses[1][0], null)
      name = proxmox_virtual_environment_vm.observability.name
    }
  }
}