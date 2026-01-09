# Current State (IST) - Dell Switch, Flat Network
# This environment represents the infrastructure BEFORE HP Switch/VLAN migration

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
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

# Provider configuration is inherited from root module
# or specify here if running independently

# === Production VMs (Current State) ===

module "truenas" {
  source = "../../modules/proxmox-vm"

  name        = "truenas-prod-cz-01"
  vmid        = 4000
  target_node = "pve-prod-cz-loki"
  description = "TrueNAS CORE - NAS Storage (IST: Single NIC, no VLANs)"

  # Resources
  cores     = 6
  sockets   = 1
  cpu_type  = "host"
  memory    = 32768 # 32 GB
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

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
  ip_address = "10.0.1.20/24"
  gateway    = "10.0.1.1"

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
  cores     = 4
  sockets   = 1
  cpu_type  = "host"
  memory    = 8192 # 8 GB
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

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
  ip_address = "10.0.1.30/24"
  gateway    = "10.0.1.1"

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

  name        = "the-arr-stack"
  vmid        = 1100
  target_node = "pve-prod-cz-loki"
  description = "Sonarr, Radarr, Lidarr, Prowlarr (IST: Single NIC)"

  # Resources
  cores     = 4
  sockets   = 1
  cpu_type  = "host"
  memory    = 8192 # 8 GB
  disk_size = "64G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

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
  ip_address = "10.0.1.90/24"
  gateway    = "10.0.1.1"

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

  name        = "docker-prod"
  vmid        = 2000
  target_node = "pve-prod-cz-loki"
  description = "Docker Production Host (IST: Single NIC)"

  # Resources
  cores     = 4
  sockets   = 1
  cpu_type  = "host"
  memory    = 16384 # 16 GB
  disk_size = "128G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

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
  ip_address = "10.0.1.50/24"
  gateway    = "10.0.1.1"

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
  cores     = 4
  sockets   = 1
  cpu_type  = "host"
  memory    = 8192 # 8 GB
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

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
  ip_address = "10.0.1.100/24"
  gateway    = "10.0.1.1"

  # VM Settings
  clone_template      = null
  full_clone          = true
  start_on_boot       = true
  qemu_agent_enabled  = true
  balloon_memory      = 0

  # Tags
  tags = ["production", "nextcloud", "current-state", "ansible:nextcloud"]
}
