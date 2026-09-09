provider "proxmox" {
    endpoint  = var.proxmox_endpoint
    api_token = var.proxmox_api_token
    insecure  = var.proxmox_insecure   # true only if using self-signed cert

    ssh {
        username = "root" # we will replace later
        private_key = file(var.ssh_private_key)

        node {
            name = var.proxmox_node
            address = var.proxmox_host_address
        }
    }

}


