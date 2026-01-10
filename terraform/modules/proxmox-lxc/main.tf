# Proxmox LXC Container Module
# Reusable module for creating Proxmox LXC containers
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

resource "proxmox_virtual_environment_container" "container" {
  # Basic Container Configuration
  vm_id       = var.vmid
  node_name   = var.target_node
  description = var.description

  # Template Configuration (optional - only for cloned containers)
  dynamic "clone" {
    for_each = var.template_vmid != null ? [1] : []

    content {
      vm_id = var.template_vmid
    }
  }

  # Hostname and User Configuration
  initialization {
    hostname = var.name

    # SSH Public Keys for root user (recommended for security)
    dynamic "user_account" {
      for_each = length(var.ssh_public_keys) > 0 || var.root_password != null ? [1] : []

      content {
        keys     = length(var.ssh_public_keys) > 0 ? var.ssh_public_keys : null
        password = var.root_password
      }
    }
  }

  # CPU Configuration
  cpu {
    cores = var.cores
  }

  # Memory Configuration (in MB)
  memory {
    dedicated = var.memory
    swap      = var.swap
  }

  # Disk Configuration
  disk {
    datastore_id = var.storage_pool
    size         = var.disk_size
  }

  # Network Configuration
  network_interface {
    name     = "eth0"
    bridge   = var.bridge
    vlan_id  = var.vlan_tag
    firewall = var.firewall_enabled
  }

  # Operating System Configuration
  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }

  # Container Features
  unprivileged = var.unprivileged

  # Boot Configuration
  started       = var.started
  start_on_boot = var.start_on_boot

  # Startup Order Configuration (optional)
  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []

    content {
      order      = var.startup_order
      up_delay   = var.startup_delay
      down_delay = var.shutdown_timeout
    }
  }

  # Protection (prevents accidental deletion)
  protection = var.protection

  # Tags for organization and Ansible dynamic inventory
  tags = var.tags

  # Lifecycle Management
  lifecycle {
    ignore_changes = [
      description,       # Keep Proxmox Helper Scripts descriptions
      network_interface, # Network can be modified manually in Proxmox
      initialization,    # Hostname/DNS changes ignored
      console,           # Console settings can be modified
      operating_system,  # OS type is set during creation
      clone,             # Clone settings are immutable after creation
    ]
  }
}
