# ============================================================================
# Proxmox VM Module Variables (bpg/proxmox)
# Structured following Proxmox GUI Tabs: General → OS → System → Disks → CPU → Memory → Network
# ============================================================================

# ============================================================================
# TAB: General
# ============================================================================

variable "name" {
  description = "VM hostname (must be unique in Proxmox cluster)"
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 63
    error_message = "VM name must be between 1 and 63 characters long."
  }
}

variable "vmid" {
  description = "Proxmox VM ID (100-999999999)"
  type        = number

  validation {
    condition     = var.vmid >= 100 && var.vmid <= 999999999
    error_message = "VM ID must be between 100 and 999999999."
  }
}

variable "target_node" {
  description = "Proxmox node where the VM should run (e.g. 'pve-prod-cz-loki')"
  type        = string
}

variable "description" {
  description = "VM description (optional, e.g. URL or purpose)"
  type        = string
  default     = ""
}

variable "start_on_boot" {
  description = "Start VM automatically when Proxmox boots"
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
  description = "Delay in seconds after VM start (0 = default)"
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
  description = "Tags for organization and Ansible dynamic inventory (e.g. ['production', 'ubuntu', 'vlan:30'])"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for tag in var.tags : can(regex("^[a-zA-Z0-9:_-]+$", tag))])
    error_message = "Tags may only contain alphanumeric characters, colons, underscores and hyphens."
  }
}

# ============================================================================
# TAB: OS (Operating System)
# ============================================================================

variable "os_type" {
  description = "Guest operating system type (l26 = Linux 2.6+, l24 = Linux 2.4, win11 = Windows 11, etc.)"
  type        = string
  default     = "l26"

  validation {
    condition     = contains(["l26", "l24", "win11", "win10", "win8", "win7", "wxp", "w2k", "solaris", "other"], var.os_type)
    error_message = "Invalid OS type. Valid values: l26, l24, win11, win10, win8, win7, wxp, w2k, solaris, other."
  }
}

# ============================================================================
# TAB: System (Hardware Emulation)
# ============================================================================

variable "bios" {
  description = "BIOS implementation (seabios = Legacy BIOS, ovmf = UEFI)"
  type        = string
  default     = "seabios"

  validation {
    condition     = contains(["seabios", "ovmf"], var.bios)
    error_message = "BIOS must be either 'seabios' or 'ovmf'."
  }
}

variable "machine" {
  description = "VM machine type (null = i440FX, q35 = modern PCIe chipset)"
  type        = string
  default     = null

  validation {
    condition     = var.machine == null || contains(["q35"], var.machine)
    error_message = "Machine must be null (i440FX) or 'q35'."
  }
}

variable "scsi_hardware" {
  description = "SCSI controller type (virtio-scsi-single, virtio-scsi-pci, lsi, lsi53c810, megasas, pvscsi)"
  type        = string
  default     = "virtio-scsi-single"

  validation {
    condition     = contains(["virtio-scsi-single", "virtio-scsi-pci", "lsi", "lsi53c810", "megasas", "pvscsi"], var.scsi_hardware)
    error_message = "Invalid SCSI controller type."
  }
}

variable "qemu_agent_enabled" {
  description = "Enable QEMU guest agent (requires qemu-guest-agent in VM)"
  type        = bool
  default     = true
}

variable "keyboard_layout" {
  description = "Keyboard layout for VM console (de, en-us, fr, etc.)"
  type        = string
  default     = "de"
}

variable "protection" {
  description = "Enable VM protection (prevents accidental deletion)"
  type        = bool
  default     = false
}

# ============================================================================
# TAB: Disks
# ============================================================================

variable "disks" {
  description = "List of disks for the VM (multi-disk support)"
  type = list(object({
    datastore_id = string           # Storage pool (e.g. "local-zfs", "local-hdd01")
    interface    = string           # scsi0, scsi1, virtio0, sata0, ide0, etc.
    size         = number           # Disk size in GB
    file_format  = optional(string) # raw, qcow2, vmdk (default: raw)
    cache        = optional(string) # none, directsync, writethrough, writeback, unsafe (default: none)
    iothread     = optional(bool)   # Enable I/O thread (default: true for VirtIO)
    ssd          = optional(bool)   # SSD emulation (default: false)
    discard      = optional(bool)   # TRIM/Discard support (default: false)
    backup       = optional(bool)   # Include in backups (default: true)
  }))
  default = []

  validation {
    condition = alltrue([
      for disk in var.disks :
      can(regex("^(scsi|virtio|sata|ide)\\d+$", disk.interface))
    ])
    error_message = "Disk interface must have format: scsi0, virtio0, sata0, ide0, etc."
  }
}


# ============================================================================
# TAB: CPU
# ============================================================================

variable "cores" {
  description = "Number of CPU cores per socket"
  type        = number
  default     = 2

  validation {
    condition     = var.cores >= 1 && var.cores <= 256
    error_message = "CPU cores must be between 1 and 256."
  }
}

variable "sockets" {
  description = "Number of CPU sockets"
  type        = number
  default     = 1

  validation {
    condition     = var.sockets >= 1 && var.sockets <= 4
    error_message = "CPU sockets must be between 1 and 4."
  }
}

variable "cpu_type" {
  description = "CPU type (host = best performance, x86-64-v2-AES = migration-capable)"
  type        = string
  default     = "host"
}

variable "cpu_limit" {
  description = "CPU limit (0 = unlimited, 1-128 = cores limit)"
  type        = number
  default     = 0

  validation {
    condition     = var.cpu_limit >= 0 && var.cpu_limit <= 128
    error_message = "CPU limit must be between 0 (unlimited) and 128."
  }
}

variable "cpu_units" {
  description = "CPU weighting for scheduler (100-500000, default: 1024)"
  type        = number
  default     = 1024

  validation {
    condition     = var.cpu_units >= 100 && var.cpu_units <= 500000
    error_message = "CPU units must be between 100 and 500000."
  }
}

variable "numa_enabled" {
  description = "Enable NUMA (Non-Uniform Memory Access)"
  type        = bool
  default     = false
}

# ============================================================================
# TAB: Memory
# ============================================================================

variable "memory" {
  description = "RAM in MB (dedicated memory)"
  type        = number
  default     = 2048

  validation {
    condition     = var.memory >= 512 && var.memory <= 1048576
    error_message = "Memory must be between 512 MB and 1 TB."
  }
}

variable "balloon_memory" {
  description = "Minimum memory for ballooning (0 = disabled, >0 = minimum MB)"
  type        = number
  default     = 0

  validation {
    condition     = var.balloon_memory >= 0
    error_message = "Balloon memory cannot be negative."
  }
}

# ============================================================================
# TAB: Network
# ============================================================================

variable "network_interfaces" {
  description = "List of network interfaces for multi-NIC support"
  type = list(object({
    model            = string           # virtio, e1000, e1000e, rtl8139, vmxnet3
    bridge           = string           # vmbr0, vmbr1, vmbr_storage, etc.
    vlan_tag         = optional(number) # VLAN ID (10, 20, 30, or null)
    firewall_enabled = optional(bool)   # Enable Proxmox firewall (default: false)
    mac_address      = optional(string) # Custom MAC address (optional)
    mtu              = optional(number) # MTU size (1 = bridge MTU, standard: 1500)
    rate_limit       = optional(number) # Bandwidth limit in MB/s (0 = unlimited)
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

  validation {
    condition = alltrue([
      for nic in var.network_interfaces :
      contains(["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3"], nic.model)
    ])
    error_message = "Network model must be one of: virtio, e1000, e1000e, rtl8139, vmxnet3."
  }
}

# ============================================================================
# ADVANCED: PCI Passthrough (GPU, HBA, NIC, etc.)
# ============================================================================

variable "hostpci_devices" {
  description = "PCI devices to pass through to VM (GPU, HBA, NIC, etc.)"
  type = list(object({
    device = string         # PCI address (e.g. "0000:08:00", "0000:88:00")
    pcie   = optional(bool) # PCIe instead of PCI (default: true)
    rombar = optional(bool) # Enable option ROM (default: true)
    xvga   = optional(bool) # Primary GPU (default: false)
  }))
  default = []

  validation {
    condition = alltrue([
      for pci in var.hostpci_devices :
      can(regex("^[0-9a-fA-F]{4}:[0-9a-fA-F]{2}:[0-9a-fA-F]{2}(\\.[0-9])?$", pci.device))
    ])
    error_message = "PCI device address must have format: 0000:00:00 or 0000:00:00.0"
  }
}

# ============================================================================
# ADVANCED: Cloud-Init (Optional - for templates only)
# ============================================================================

variable "ip_address" {
  description = "Static IP address for Cloud-Init (CIDR, e.g. '10.0.30.20/24', null = no Cloud-Init)"
  type        = string
  default     = null

  validation {
    condition     = var.ip_address == null || can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+/\\d+$", var.ip_address))
    error_message = "IP address must have CIDR format (e.g. '10.0.30.20/24')."
  }
}

variable "gateway" {
  description = "Default gateway for Cloud-Init"
  type        = string
  default     = null

  validation {
    condition     = var.gateway == null || can(regex("^\\d+\\.\\d+\\.\\d+\\.\\d+$", var.gateway))
    error_message = "Gateway must be a valid IP address (e.g. '10.0.30.1')."
  }
}

# ============================================================================
# ADVANCED: Template & Cloning
# ============================================================================

variable "clone_template" {
  description = "Template VM ID to clone from (null = create from scratch)"
  type        = number
  default     = null
}

variable "full_clone" {
  description = "Full clone instead of linked clone (only relevant if clone_template is set)"
  type        = bool
  default     = true
}
