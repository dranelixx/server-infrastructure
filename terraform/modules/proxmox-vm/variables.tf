# Proxmox VM Module Variables

# === Basic VM Configuration ===

variable "name" {
  description = "VM name (must be unique within Proxmox cluster)"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 63
    error_message = "VM name must be between 1 and 63 characters."
  }
}

variable "vmid" {
  description = "Proxmox VM ID (100-999999)"
  type        = number

  validation {
    condition     = var.vmid >= 100 && var.vmid <= 999999
    error_message = "VM ID must be between 100 and 999999."
  }
}

variable "target_node" {
  description = "Proxmox node name (e.g., 'pve-prod-cz-loki')"
  type        = string
}

variable "description" {
  description = "VM description (optional)"
  type        = string
  default     = ""
}

# === CPU Configuration ===

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2

  validation {
    condition     = var.cores >= 1 && var.cores <= 128
    error_message = "CPU cores must be between 1 and 128."
  }
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1
}

variable "cpu_type" {
  description = "CPU type (host, kvm64, etc.)"
  type        = string
  default     = "host"
}

# === Memory Configuration ===

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 512 && var.memory <= 1048576
    error_message = "Memory must be between 512 MB and 1 TB."
  }
}

variable "balloon_memory" {
  description = "Enable memory ballooning (0 = disabled)"
  type        = number
  default     = 0
}

# === Storage Configuration ===

variable "disk_size" {
  description = "Disk size (e.g., '32G', '100G')"
  type        = string
  default     = "32G"

  validation {
    condition     = can(regex("^\\d+[GMK]$", var.disk_size))
    error_message = "Disk size must be in format: number + G/M/K (e.g., '32G')."
  }
}

variable "storage_pool" {
  description = "Storage pool name (e.g., 'local-zfs', 'local-hdd01')"
  type        = string
  default     = "local-zfs"
}

variable "emulate_ssd" {
  description = "Emulate SSD for better performance with SSDs"
  type        = bool
  default     = true
}

# === Network Configuration ===

variable "network_interfaces" {
  description = "List of network interfaces for multi-NIC support"
  type = list(object({
    model            = string           # virtio, e1000, etc.
    bridge           = string           # vmbr0, vmbr_storage, etc.
    vlan_tag         = optional(number) # VLAN ID (10, 20, 30, or null)
    firewall_enabled = optional(bool)   # Enable Proxmox firewall (default: false)
    mac_address      = optional(string) # Custom MAC address (optional)
  }))

  default = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  validation {
    condition     = length(var.network_interfaces) >= 1 && length(var.network_interfaces) <= 8
    error_message = "VM must have between 1 and 8 network interfaces."
  }
}

variable "ip_address" {
  description = "Static IP address (CIDR notation, e.g., '10.0.30.20/24')"
  type        = string
  default     = null

  validation {
    condition = var.ip_address == null || can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+/\\d+$", var.ip_address))
    error_message = "IP address must be in CIDR format (e.g., '10.0.30.20/24')."
  }
}

variable "gateway" {
  description = "Default gateway IP address"
  type        = string
  default     = null

  validation {
    condition = var.gateway == null || can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.gateway))
    error_message = "Gateway must be a valid IP address (e.g., '10.0.30.1')."
  }
}

# === Template & Cloning ===

variable "clone_template" {
  description = "Template name to clone from (null = create from scratch)"
  type        = string
  default     = null
}

variable "full_clone" {
  description = "Full clone instead of linked clone"
  type        = bool
  default     = true
}

# === Boot & Agent ===

variable "start_on_boot" {
  description = "Start VM automatically on Proxmox boot"
  type        = bool
  default     = true
}

variable "qemu_agent_enabled" {
  description = "Enable QEMU Guest Agent (requires agent installed in VM)"
  type        = bool
  default     = true
}

# === Tags for Organization ===

variable "tags" {
  description = "Tags for organization and Ansible dynamic inventory (e.g., ['production', 'ubuntu', 'vlan:30'])"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for tag in var.tags : can(regex("^[a-zA-Z0-9:_-]+$", tag))])
    error_message = "Tags must contain only alphanumeric characters, colons, underscores, and hyphens."
  }
}
