# Current State (Current) - Dell Switch, Flat Network
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
  cores    = 6
  sockets  = 1
  cpu_type = "host"
  memory   = 32768 # 32 GB

  # Disks - Multi-disk configuration
  disks = [
    {
      datastore_id = "local-zfs"
      interface    = "scsi0"
      size         = 48
      iothread     = true
      ssd          = false
    },
    {
      datastore_id = "local-hdd01"
      interface    = "scsi1"
      size         = 128
      iothread     = true
      ssd          = false
    }
  ]

  # PCI Passthrough - HBA Controller
  hostpci_devices = [
    {
      device = "0000:08:00"
      pcie   = true
      rombar = true
    }
  ]

  # Boot order
  startup_order = 1

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - Current: Dual NIC on flat network (vmbr0, vmbr1, no VLAN)
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    },
    {
      model            = "virtio"
      bridge           = "vmbr1"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # VM Settings
  clone_template     = null
  full_clone         = true
  start_on_boot      = true
  qemu_agent_enabled = true
  balloon_memory     = 0

  # Tags
  tags = ["production", "storage", "truenas", "ansible-truenas"]
}

module "pms" {
  source = "../../modules/proxmox-vm"

  name        = "pms-prod-cz-01"
  vmid        = 1000
  target_node = "pve-prod-cz-loki"
  description = "Plex Media Server (Current: Single NIC)"

  # Resources
  cores     = 6
  sockets   = 1
  cpu_type  = "host"
  memory    = 20480 # 20 GB (10GB /dev/shm + overhead for 3-4 streams)
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # PCI Passthrough - GPU
  hostpci_devices = [
    {
      device = "0000:88:00"
      pcie   = true
      rombar = true
    }
  ]

  # Boot order
  startup_order = 2

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - Current: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # VM Settings
  clone_template     = null
  full_clone         = true
  start_on_boot      = true
  qemu_agent_enabled = true
  balloon_memory     = 0

  # Tags
  tags = ["production", "media", "plex", "ansible-plex"]
}

module "arr_stack" {
  source = "../../modules/proxmox-vm"

  name        = "the-arr-stack-prod-01"
  vmid        = 1100
  target_node = "pve-prod-cz-loki"
  description = "https://the-arr-stack-prod-cz-01.getinn.top/"

  # Resources
  cores     = 4
  sockets   = 1
  cpu_type  = "x86-64-v2-AES"
  memory    = 8192 # 8 GB
  disk_size = "64G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - Current: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # VM Settings
  clone_template     = null
  full_clone         = true
  start_on_boot      = true
  qemu_agent_enabled = true
  balloon_memory     = 0

  # Tags
  tags = ["production", "media", "arr-stack", "ansible-arr_stack"]
}

module "docker_prod" {
  source = "../../modules/proxmox-vm"

  name        = "docker-prod-cz-01"
  vmid        = 2000
  target_node = "pve-prod-cz-loki"
  description = "https://docker-prod-cz-01.getinn.top/"

  # Resources
  cores     = 6
  sockets   = 1
  cpu_type  = "host"
  memory    = 12288 # 12 GB
  disk_size = "128G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - Current: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # VM Settings
  clone_template     = null
  full_clone         = true
  start_on_boot      = true
  qemu_agent_enabled = true
  balloon_memory     = 0

  # Tags
  tags = ["production", "docker", "ansible-docker"]
}

module "nextcloud" {
  source = "../../modules/proxmox-vm"

  name        = "nextcloud-prod-cz-01"
  vmid        = 8000
  target_node = "pve-prod-cz-loki"
  description = "Nextcloud Instance (Current: Single NIC)"

  # Resources
  cores     = 12
  sockets   = 1
  cpu_type  = "host"
  memory    = 16384 # 16 GB (increased due to swapping)
  disk_size = "100G"

  # Storage
  storage_pool = "local-zfs"
  emulate_ssd  = true

  # Hardware Emulation
  bios       = "ovmf"
  machine    = "q35"
  protection = true

  # Network - Current: Single NIC
  network_interfaces = [
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = null
      firewall_enabled = false
    }
  ]

  # VM Settings
  clone_template     = null
  full_clone         = true
  start_on_boot      = true
  qemu_agent_enabled = true
  balloon_memory     = 0

  # Tags
  tags = ["production", "nextcloud", "ansible-nextcloud"]
}

# === Production LXC Containers (Current State) ===

# Monitoring Infrastructure
module "prometheus" {
  source = "../../modules/proxmox-lxc"

  name        = "prometheus-prod-cz-01"
  vmid        = 3000
  target_node = "pve-prod-cz-loki"
  description = "Prometheus Monitoring Server"

  # Resources
  cores  = 2
  memory = 512
  swap   = 512

  # Storage
  disk_size    = 4
  storage_pool = "local-ssd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "monitoring", "ansible-prometheus", "alpine", "database", "proxmox-helper-scripts"]
}

module "influxdbv2" {
  source = "../../modules/proxmox-lxc"

  name        = "influxdbv2-prod-cz-01"
  vmid        = 3002
  target_node = "pve-prod-cz-loki"
  description = "InfluxDB v2 Time-Series Database"

  # Resources
  cores  = 2
  memory = 4096
  swap   = 512

  # Storage
  disk_size    = 8
  storage_pool = "local-ssd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "monitoring", "ansible-influxdb", "debian", "proxmox-helper-scripts"]
}

# Pterodactyl Game Panel Infrastructure
module "ptero_panel" {
  source = "../../modules/proxmox-lxc"

  name        = "ptero-panel-prod-cz-01"
  vmid        = 5000
  target_node = "pve-prod-cz-loki"
  description = "Pterodactyl Panel (Game Server Management)"

  # Resources
  cores  = 2
  memory = 1024
  swap   = 512

  # Storage
  disk_size    = 8
  storage_pool = "local-zfs"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = true

  # Tags
  tags = ["production", "lxc", "gaming", "ansible-pterodactyl", "panel", "ubuntu"]
}

module "ptero_wings" {
  source = "../../modules/proxmox-lxc"

  name        = "ptero-wings-prod-cz-01"
  vmid        = 5001
  target_node = "pve-prod-cz-loki"
  description = "Pterodactyl Wings (Game Server Daemon)"

  # Resources
  cores  = 24
  memory = 32768
  swap   = 16384

  # Storage
  disk_size    = 200
  storage_pool = "local-hdd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "gaming", "ansible-pterodactyl", "ubuntu", "wings"]
}

module "ptero_mariadb" {
  source = "../../modules/proxmox-lxc"

  name        = "ptero-mariadb-prod-cz-01"
  vmid        = 5050
  target_node = "pve-prod-cz-loki"
  description = "MariaDB Database for Pterodactyl"

  # Resources
  cores  = 2
  memory = 1024
  swap   = 512

  # Storage
  disk_size    = 28
  storage_pool = "local-ssd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "database", "ansible-mariadb", "debian", "mysql"]
}

# Development Containers (Stopped)
module "ptero_wings_devel" {
  source = "../../modules/proxmox-lxc"

  name        = "ptero-wings-development-cz-01"
  vmid        = 5998
  target_node = "pve-prod-cz-loki"
  description = "Pterodactyl Wings Development Environment"

  # Resources
  cores  = 4
  memory = 4096
  swap   = 1024

  # Storage
  disk_size    = 12
  storage_pool = "local-zfs"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = false
  started       = false
  protection    = false

  # Tags
  tags = ["development", "lxc", "gaming", "ubuntu", "wings"]
}

module "ptero_panel_devel" {
  source = "../../modules/proxmox-lxc"

  name        = "ptero-panel-development-cz-01"
  vmid        = 5999
  target_node = "pve-prod-cz-loki"
  description = "Pterodactyl Panel Development Environment"

  # Resources
  cores  = 4
  memory = 4096
  swap   = 1024

  # Storage
  disk_size    = 8
  storage_pool = "local-zfs"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = false
  started       = false
  protection    = false

  # Tags
  tags = ["development", "lxc", "gaming", "panel", "ubuntu"]
}

# IT Infrastructure Management
module "netbox" {
  source = "../../modules/proxmox-lxc"

  name        = "netbox-prod-cz-01"
  vmid        = 6000
  target_node = "pve-prod-cz-loki"
  description = "NetBox IPAM and DCIM"

  # Resources
  cores  = 2
  memory = 3072
  swap   = 1024

  # Storage
  disk_size    = 16
  storage_pool = "local-zfs"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = true

  # Tags
  tags = ["production", "lxc", "infrastructure", "ansible-netbox", "development", "ubuntu"]
}

module "trilium" {
  source = "../../modules/proxmox-lxc"

  name        = "trilium-prod-cz-01"
  vmid        = 6100
  target_node = "pve-prod-cz-loki"
  description = "Trilium Notes - Personal Knowledge Base"

  # Resources
  cores  = 1
  memory = 1024
  swap   = 512

  # Storage
  disk_size    = 8
  storage_pool = "local-zfs"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = false
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "productivity", "ansible-trilium", "debian", "proxmox-helper-scripts"]
}

module "syncthing" {
  source = "../../modules/proxmox-lxc"

  name        = "syncthing-prod-cz-01"
  vmid        = 6101
  target_node = "pve-prod-cz-loki"
  description = "Syncthing File Synchronization"

  # Resources
  cores  = 2
  memory = 2048
  swap   = 512

  # Storage
  disk_size    = 50
  storage_pool = "local-hdd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = false
  started       = false
  protection    = false

  # Tags
  tags = ["production", "lxc", "productivity", "ansible-syncthing", "proxmox-helper-scripts"]
}

module "vscode" {
  source = "../../modules/proxmox-lxc"

  name        = "vscode-prod-cz-01"
  vmid        = 6102
  target_node = "pve-prod-cz-loki"
  description = "VS Code Server - Remote Development"

  # Resources
  cores  = 8
  memory = 8192
  swap   = 512

  # Storage
  disk_size    = 20
  storage_pool = "local-ssd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = false
  started       = false
  protection    = false

  # Tags
  tags = ["production", "lxc", "ansible-vscode", "community-script", "debian", "os", "vscode"]
}

module "ptero_panel_devel_02" {
  source = "../../modules/proxmox-lxc"

  name        = "ptero-panel-development-02"
  vmid        = 6103
  target_node = "pve-prod-cz-loki"
  description = "Pterodactyl Panel Development Environment #2"

  # Resources
  cores  = 4
  memory = 4096
  swap   = 512

  # Storage
  disk_size    = 22
  storage_pool = "local"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = false
  started       = false
  protection    = false

  # Tags
  tags = ["development", "lxc", "gaming", "panel", "ubuntu"]
}

# Logging Infrastructure
module "graylog" {
  source = "../../modules/proxmox-lxc"

  name        = "graylog-prod-cz-01"
  vmid        = 9000
  target_node = "pve-prod-cz-loki"
  description = "Graylog Centralized Logging"

  # Resources
  cores  = 4
  memory = 12288
  swap   = 4096

  # Storage
  disk_size    = 130
  storage_pool = "local-hdd01"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = true

  # Tags
  tags = ["production", "lxc", "logging", "ansible-graylog", "community-script"]
}

# === CI/CD Infrastructure ===

module "github_runner" {
  source = "../../modules/proxmox-lxc"

  name        = "github-runner-prod-cz-01"
  vmid        = 6200
  target_node = "pve-prod-cz-loki"
  description = "GitHub Actions Self-Hosted Runner for Terraform Workflows"

  # Resources
  cores  = 2
  memory = 2048
  swap   = 512

  # Storage
  disk_size    = 20
  storage_pool = "local-zfs"

  # Network
  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  # Template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "cicd", "github-runner", "ansible-github-runner"]
}
