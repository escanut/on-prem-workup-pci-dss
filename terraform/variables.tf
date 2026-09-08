variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (e.g. https://192.168.1.10:8006/)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form user@realm!tokenid=secret"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification (self-signed certs)"
  type        = bool
  default     = true
}

# VM setup
variable "proxmox_node" {
  description = "Proxmox node name (e.g. pve)"
  type        = string
}

variable "datastore_id" {
  description = "Datastore for VM disks (e.g. local-lvm)"
  type        = string
  default     = "local-lvm"
}

variable "vm_name" {
  description = "Name of the VM"
  type        = string
  default     = "ubuntu-test"
}

variable "vm_id" {
  description = "VMID to use (leave null for auto)"
  type        = number
  default     = null
}

variable "ip_config" {
  description = "Static IP configuration"
  type = object({
    address = string   # e.g. "192.168.1.50/24"
    gateway = string   # e.g. "192.168.1.1"
  })
  default = null
}

variable "ssh_private_key" {
  description = "Static IP configuration"
  type = string
  default = "~/.ssh/id_ed25519"
}

variable "proxmox_host_address" {
  description = "Proxmox host address)"
  type = string
}