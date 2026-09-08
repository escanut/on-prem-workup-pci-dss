output "vms" {
  value = {
    template = {
      id = proxmox_virtual_environment_vm.ubuntu_template.vm_id
    }
    frontend = {
      id   = proxmox_virtual_environment_vm.frontend.vm_id
      ip   = try(proxmox_virtual_environment_vm.frontend.ipv4_addresses[1][0], null)
      name = proxmox_virtual_environment_vm.frontend.name
    }
   
  }
}