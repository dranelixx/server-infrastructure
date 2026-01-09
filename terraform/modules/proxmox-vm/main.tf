# Proxmox VM Module
# Reusable module for creating Proxmox VMs with multi-NIC and VLAN support
# Provider: bpg/proxmox (v0.91.0+)

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.91.0"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  # Basic VM Configuration
  name        = var.name
  node_name   = var.target_node
  vm_id       = var.vmid
  description = var.description

  # Hardware Emulation
  bios            = var.bios
  machine         = var.machine
  protection      = var.protection
  keyboard_layout = var.keyboard_layout

  # EFI Disk (required for UEFI/OVMF BIOS)
  dynamic "efi_disk" {
    for_each = var.bios == "ovmf" ? [1] : []

    content {
      datastore_id      = var.storage_pool
      file_format       = "raw"
      type              = "4m"
      pre_enrolled_keys = true
    }
  }

  # Clone from template (if specified)
  dynamic "clone" {
    for_each = var.clone_template != null ? [1] : []

    content {
      vm_id = var.clone_template
      full  = var.full_clone
    }
  }

  # CPU Configuration
  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = var.cpu_type
  }

  # Memory Configuration (in MB)
  memory {
    dedicated = var.memory
    floating  = var.balloon_memory > 0 ? var.balloon_memory : var.memory
  }

  # Disk Configuration
  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = parseint(replace(var.disk_size, "/[GMK]/", ""), 10)
    file_format  = "raw"
    iothread     = true
    discard      = "on"
    ssd          = var.emulate_ssd
  }

  # Network Interfaces (supports multiple NICs)
  dynamic "network_device" {
    for_each = var.network_interfaces

    content {
      model    = network_device.value.model
      bridge   = network_device.value.bridge
      vlan_id  = network_device.value.vlan_tag
      firewall = try(network_device.value.firewall_enabled, false)
      mac_address = try(network_device.value.mac_address, null)
    }
  }

  # Cloud-Init / Static IP Configuration (only if IP is configured)
  dynamic "initialization" {
    for_each = var.ip_address != null ? [1] : []

    content {
      ip_config {
        ipv4 {
          address = var.ip_address
          gateway = var.gateway
        }
      }
    }
  }

  # Boot Configuration
  on_boot = var.start_on_boot
  agent {
    enabled = var.qemu_agent_enabled
  }

  # Operating System Type (Linux 2.6+ Kernel)
  operating_system {
    type = "l26"
  }

  # Tags for organization and Ansible dynamic inventory
  tags = var.tags

  # Lifecycle Management
  lifecycle {
    ignore_changes = [
      network_device,  # NICs can be modified manually in Proxmox
      disk,            # Disk size growth is ignored
      initialization,  # Cloud-init changes ignored (VMs may not use cloud-init)
      efi_disk,        # EFI disk location may vary
      boot_order,      # Boot order can change
      ipv4_addresses,  # Runtime IP addresses
      ipv6_addresses,  # Runtime IPv6 addresses
      mac_addresses,   # MAC addresses
      network_interface_names, # Runtime interface names
    ]
  }
}
