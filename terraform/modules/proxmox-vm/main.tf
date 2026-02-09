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
      datastore_id      = var.disks[0].datastore_id
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
    limit   = var.cpu_limit > 0 ? var.cpu_limit : null
    units   = var.cpu_units
    numa    = var.numa_enabled
  }

  # Memory Configuration (in MB)
  memory {
    dedicated = var.memory
    floating  = var.balloon_memory > 0 ? var.balloon_memory : var.memory
  }

  # Disk Configuration (Multi-Disk Support)
  dynamic "disk" {
    for_each = var.disks

    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = try(disk.value.file_format, "raw")
      cache        = try(disk.value.cache, "none")
      iothread     = try(disk.value.iothread, true)
      ssd          = try(disk.value.ssd, false)
      discard      = coalesce(disk.value.discard, false) ? "on" : "ignore"
      backup       = try(disk.value.backup, true)
    }
  }

  # SCSI Controller Configuration
  scsi_hardware = var.scsi_hardware

  # Network Interfaces (supports multiple NICs)
  dynamic "network_device" {
    for_each = var.network_interfaces

    content {
      model       = network_device.value.model
      bridge      = network_device.value.bridge
      vlan_id     = network_device.value.vlan_tag
      firewall    = try(network_device.value.firewall_enabled, false)
      mac_address = try(network_device.value.mac_address, null)
      mtu         = try(network_device.value.mtu, null)
      rate_limit  = try(network_device.value.rate_limit, null)
    }
  }

  # PCI Passthrough (GPU, HBA, NIC, etc.)
  dynamic "hostpci" {
    for_each = var.hostpci_devices

    content {
      device = hostpci.value.device
      pcie   = try(hostpci.value.pcie, true)
      rombar = try(hostpci.value.rombar, true)
      xvga   = try(hostpci.value.xvga, false)
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

  # Startup Order Configuration (optional)
  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []

    content {
      order      = var.startup_order
      up_delay   = var.startup_delay
      down_delay = var.shutdown_timeout
    }
  }

  # QEMU Guest Agent
  agent {
    enabled = var.qemu_agent_enabled
  }

  # Operating System Type
  operating_system {
    type = var.os_type
  }

  # Tags for organization and Ansible dynamic inventory
  tags = var.tags

  # Lifecycle Management
  lifecycle {
    ignore_changes = [
      network_device, # NICs can be modified manually in Proxmox
      initialization, # Cloud-init changes ignored (VMs may not use cloud-init)
      efi_disk,       # EFI disk location may vary
      boot_order,     # Boot order can change
      hostpci,        # PCI passthrough can be modified manually
    ]
  }
}
