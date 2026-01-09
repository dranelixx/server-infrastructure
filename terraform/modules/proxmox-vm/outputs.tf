# Proxmox VM Module Outputs

output "vmid" {
  description = "The Proxmox VM ID"
  value       = proxmox_vm_qemu.vm.vmid
}

output "name" {
  description = "The VM name"
  value       = proxmox_vm_qemu.vm.name
}

output "id" {
  description = "The full Proxmox resource ID (node/type/vmid)"
  value       = proxmox_vm_qemu.vm.id
}

output "ipv4_address" {
  description = "The primary IPv4 address (from cloud-init or variable)"
  value       = var.ip_address != null ? split("/", var.ip_address)[0] : null
}

output "network_interfaces" {
  description = "Network interfaces configuration"
  value       = var.network_interfaces
}

output "tags" {
  description = "VM tags (for Ansible inventory)"
  value       = var.tags
}

output "target_node" {
  description = "Proxmox node where VM is running"
  value       = var.target_node
}

output "resource_specs" {
  description = "VM resource specifications"
  value = {
    cores   = var.cores
    sockets = var.sockets
    memory  = var.memory
    disk    = var.disk_size
  }
}
