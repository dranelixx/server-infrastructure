# Current State (IST) - Dell Switch, Flat Network
# This environment represents the infrastructure BEFORE HP Switch/VLAN migration

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.91.0"
    }
  }

  # Uncomment after Terraform Cloud setup
  # cloud {
  #   organization = "YOUR-ORG-NAME"
  #   workspaces {
  #     name = "current-state"
  #   }
  # }
}

# Provider configuration for bpg/proxmox
provider "proxmox" {
  endpoint = var.proxmox_api_url
  insecure = var.proxmox_tls_insecure

  # API Token Authentication (format: "user@realm!token-id=secret")
  api_token = var.proxmox_api_token_id != null && var.proxmox_api_token_secret != null ? "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}" : null

  # Fallback: Username/Password (optional, only if api_token is null)
  username = var.proxmox_user
  password = var.proxmox_password
}

# === Production VMs (Current State) ===

module "truenas" {
  source = "../../modules/proxmox-vm"

  name        = "truenas-prod-cz-01"
  vmid        = 4000
  target_node = "pve-prod-cz-loki"
  description = "https://truenas-prod-cz-01.getinn.top/"

  # Resources
  cores     = 6
  sockets   = 1
  cpu_type  = "host"
  memory    = 32768 # 32 GB
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - IST: Single NIC on flat network (vmbr0, no VLAN)
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null # Flat network
      firewall_enabled = false
    }
  ]

  # Current IP (before migration)
  ip_address = null # Real IP: 10.0.1.20/24
  gateway    = null # Real GW: 10.0.1.1

  # VM Settings
  clone_template      = null
  full_clone          = true
  start_on_boot       = true
  qemu_agent_enabled  = true
  balloon_memory      = 0

  # Tags
  tags = ["production", "storage", "truenas", "current-state", "ansible:truenas"]
}

module "pms" {
  source = "../../modules/proxmox-vm"

  name        = "pms-prod-cz-01"
  vmid        = 1000
  target_node = "pve-prod-cz-loki"
  description = "Plex Media Server (IST: Single NIC)"

  # Resources
  cores     = 10
  sockets   = 1
  cpu_type  = "host"
  memory    = 8192 # 8 GB
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - IST: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # Current IP
  ip_address = null # Real IP: 10.0.1.30/24
  gateway    = null # Real GW: 10.0.1.1

  # VM Settings
  clone_template      = null
  full_clone          = true
  start_on_boot       = true
  qemu_agent_enabled  = true
  balloon_memory      = 0

  # Tags
  tags = ["production", "media", "plex", "current-state", "ansible:plex"]
}

module "arr_stack" {
  source = "../../modules/proxmox-vm"

  name        = "the-arr-stack-prod-01"
  vmid        = 1100
  target_node = "pve-prod-cz-loki"
  description = "https://the-arr-stack-prod-cz-01.getinn.top/"

  # Resources
  cores     = 4
  sockets   = 2
  cpu_type  = "host"
  memory    = 8192 # 8 GB
  disk_size = "64G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - IST: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # Current IP
  ip_address = null # Real IP: 10.0.1.90/24
  gateway    = null # Real GW: 10.0.1.1

  # VM Settings
  clone_template      = null
  full_clone          = true
  start_on_boot       = true
  qemu_agent_enabled  = true
  balloon_memory      = 0

  # Tags
  tags = ["production", "media", "arr-stack", "current-state", "ansible:arr_stack"]
}

module "docker_prod" {
  source = "../../modules/proxmox-vm"

  name        = "docker-prod-cz-01"
  vmid        = 2000
  target_node = "pve-prod-cz-loki"
  description = "https://docker-prod-cz-01.getinn.top/"

  # Resources
  cores     = 6
  sockets   = 2
  cpu_type  = "host"
  memory    = 16384 # 16 GB
  disk_size = "128G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - IST: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # Current IP
  ip_address = null # Real IP: 10.0.1.50/24
  gateway    = null # Real GW: 10.0.1.1

  # VM Settings
  clone_template      = null
  full_clone          = true
  start_on_boot       = true
  qemu_agent_enabled  = true
  balloon_memory      = 0

  # Tags
  tags = ["production", "docker", "current-state", "ansible:docker"]
}

module "nextcloud" {
  source = "../../modules/proxmox-vm"

  name        = "nextcloud-prod-cz-01"
  vmid        = 8000
  target_node = "pve-prod-cz-loki"
  description = "Nextcloud Instance (IST: Single NIC)"

  # Resources
  cores     = 12
  sockets   = 1
  cpu_type  = "host"
  memory    = 8192 # 8 GB
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - IST: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # Current IP
  ip_address = null # Real IP: 10.0.1.100/24
  gateway    = null # Real GW: 10.0.1.1

  # VM Settings
  clone_template      = null
  full_clone          = true
  start_on_boot       = true
  qemu_agent_enabled  = true
  balloon_memory      = 0

  # Tags
  tags = ["production", "nextcloud", "current-state", "ansible:nextcloud"]
}
