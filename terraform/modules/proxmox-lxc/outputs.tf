# Proxmox LXC Container Module Outputs (bpg/proxmox)

output "vmid" {
  description = "The Proxmox Container ID"
  value       = proxmox_virtual_environment_container.container.vm_id
}

output "name" {
  description = "The container hostname"
  value       = var.name
}

output "id" {
  description = "The full Proxmox resource ID"
  value       = proxmox_virtual_environment_container.container.id
}

output "tags" {
  description = "Container tags (for Ansible inventory)"
  value       = var.tags
}

output "target_node" {
  description = "Proxmox node where container is running"
  value       = var.target_node
}

output "resource_specs" {
  description = "Container resource specifications"
  value = {
    cores     = var.cores
    memory    = var.memory
    swap      = var.swap
    disk_size = var.disk_size
  }
}

output "network_config" {
  description = "Container network configuration"
  value = {
    bridge           = var.bridge
    vlan_tag         = var.vlan_tag
    firewall_enabled = var.firewall_enabled
  }
}
