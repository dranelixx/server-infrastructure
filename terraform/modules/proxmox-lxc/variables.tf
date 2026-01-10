# ============================================================================
# Proxmox LXC Container Module Variables (bpg/proxmox)
# Structured following Proxmox GUI Tabs: General → Resources → Disk → Network → Template
# ============================================================================

# ============================================================================
# TAB: General
# ============================================================================

variable "name" {
  description = "Container hostname (must be unique in Proxmox cluster)"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 63
    error_message = "Container name must be between 1 and 63 characters long."
  }
}

variable "vmid" {
  description = "Proxmox Container ID (100-999999999)"
  type        = number

  validation {
    condition     = var.vmid >= 100 && var.vmid <= 999999999
    error_message = "Container ID must be between 100 and 999999999."
  }
}

variable "target_node" {
  description = "Proxmox node where the container should run (e.g. 'pve-prod-cz-loki')"
  type        = string
}

variable "description" {
  description = "Container description (optional, e.g. purpose or service name)"
  type        = string
  default     = ""
}

variable "start_on_boot" {
  description = "Start container automatically when Proxmox boots"
  type        = bool
  default     = true
}

variable "started" {
  description = "Start container after creation"
  type        = bool
  default     = true
}

variable "startup_order" {
  description = "Boot order (lower numbers start first, null = any)"
  type        = number
  default     = null

  validation {
    condition     = var.startup_order == null || (var.startup_order >= 0 && var.startup_order <= 9999)
    error_message = "Startup order must be between 0 and 9999 or null."
  }
}

variable "startup_delay" {
  description = "Delay in seconds after container start (0 = default)"
  type        = number
  default     = 0

  validation {
    condition     = var.startup_delay >= 0
    error_message = "Startup delay cannot be negative."
  }
}

variable "shutdown_timeout" {
  description = "Timeout in seconds for clean shutdown (0 = default)"
  type        = number
  default     = 0

  validation {
    condition     = var.shutdown_timeout >= 0
    error_message = "Shutdown timeout cannot be negative."
  }
}

variable "tags" {
  description = "Tags for organization and Ansible dynamic inventory (e.g. ['production', 'lxc', 'monitoring'])"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for tag in var.tags : can(regex("^[a-zA-Z0-9:_-]+$", tag))])
    error_message = "Tags may only contain alphanumeric characters, colons, underscores and hyphens."
  }
}

variable "protection" {
  description = "Enable container protection (prevents accidental deletion)"
  type        = bool
  default     = false
}

# ============================================================================
# TAB: Resources
# ============================================================================

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2

  validation {
    condition     = var.cores >= 1 && var.cores <= 256
    error_message = "CPU cores must be between 1 and 256."
  }
}

variable "memory" {
  description = "RAM in MB (dedicated memory)"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 16 && var.memory <= 1048576
    error_message = "Memory must be between 16 MB and 1 TB."
  }
}

variable "swap" {
  description = "Swap space in MB"
  type        = number
  default     = 512

  validation {
    condition     = var.swap >= 0 && var.swap <= 1048576
    error_message = "Swap cannot be negative and must not exceed 1 TB."
  }
}

# ============================================================================
# TAB: Disk
# ============================================================================

variable "disk_size" {
  description = "Root filesystem size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.disk_size >= 1 && var.disk_size <= 10240
    error_message = "Disk size must be between 1 GB and 10 TB."
  }
}

variable "storage_pool" {
  description = "Storage pool name (e.g. 'local-zfs', 'local-hdd01')"
  type        = string
  default     = "local-zfs"
}

# ============================================================================
# TAB: Network
# ============================================================================

variable "bridge" {
  description = "Network bridge (e.g. 'vmbr0', 'vmbr1')"
  type        = string
  default     = "vmbr0"
}

variable "vlan_tag" {
  description = "VLAN ID (null = no VLAN tagging)"
  type        = number
  default     = null

  validation {
    condition     = var.vlan_tag == null || (var.vlan_tag >= 1 && var.vlan_tag <= 4094)
    error_message = "VLAN tag must be between 1 and 4094 or null."
  }
}

variable "firewall_enabled" {
  description = "Enable Proxmox firewall for this container"
  type        = bool
  default     = false
}

# ============================================================================
# TAB: Template & Operating System
# ============================================================================

variable "template_vmid" {
  description = "Template container ID to clone from (null = create from scratch, number = clone from template)"
  type        = number
  default     = null

  validation {
    condition     = var.template_vmid == null || (var.template_vmid >= 100 && var.template_vmid <= 999999999)
    error_message = "Template VM ID must be null or between 100 and 999999999."
  }
}

variable "template_file_id" {
  description = "OS template file ID from Proxmox storage (e.g., 'local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst')"
  type        = string
  default     = "local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"
}

variable "os_type" {
  description = "Operating system type (unmanaged, debian, ubuntu, centos, fedora, opensuse, archlinux, alpine, gentoo)"
  type        = string
  default     = "ubuntu"

  validation {
    condition     = contains(["unmanaged", "debian", "ubuntu", "centos", "fedora", "opensuse", "archlinux", "alpine", "gentoo"], var.os_type)
    error_message = "Invalid OS type. Valid values: unmanaged, debian, ubuntu, centos, fedora, opensuse, archlinux, alpine, gentoo."
  }
}

# ============================================================================
# ADVANCED: Security & Access
# ============================================================================

variable "unprivileged" {
  description = "Run container as unprivileged (recommended for security)"
  type        = bool
  default     = true
}

variable "ssh_public_keys" {
  description = "List of SSH public keys for root user access (recommended)"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for key in var.ssh_public_keys : can(regex("^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ", key))])
    error_message = "Invalid SSH public key format. Must start with ssh-rsa, ssh-ed25519, or ecdsa-sha2-nistp*."
  }
}

variable "root_password" {
  description = "Root password for container access (optional, use SSH keys instead)"
  type        = string
  default     = null
  sensitive   = true
}
