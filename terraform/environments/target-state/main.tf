# Target State Environment
# Post-Migration Architecture mit HP Switch, VLANs (10/20/30), LACP Bonding

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.91.0"
    }
  }
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

# === TrueNAS VM - Multi-homed (VLAN 30 + vmbr_storage) ===

module "truenas" {
  source = "../../modules/proxmox-vm"

  # Basic Configuration
  name        = "truenas-prod-cz-01"
  vmid        = 4000
  target_node = "pve-prod-cz-loki"
  description = "TrueNAS Storage VM - Multi-homed (Compute VLAN + Storage Bridge)"

  # Resources (from live API data)
  cores   = 6
  sockets = 1
  memory  = 32768 # 32GB

  # Storage
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

  # Multi-homed Network Configuration
  network_interfaces = [
    # net0: Compute VLAN (Management, NFS/SMB exports)
    {
      model            = "virtio"
      bridge           = "vmbr0"
      vlan_tag         = 30 # VLAN 30: Compute
      firewall_enabled = false
    },
    # net1: Internal storage network (TrueNAS ↔ Plex ↔ arr-stack)
    {
      model            = "virtio"
      bridge           = "vmbr_storage"
      vlan_tag         = null # No VLAN, internal L2 bridge
      firewall_enabled = false
    }
  ]

  # IP Configuration (VLAN 30 interface)
  ip_address = "10.0.30.20/24"
  gateway    = "10.0.30.1"

  # Boot Settings
  start_on_boot      = true
  qemu_agent_enabled = true

  # Tags for Ansible Dynamic Inventory
  tags = [
    "production",
    "ubuntu",
    "storage",
    "truenas",
    "vlan:30",
    "multi-homed",
    "ansible:truenas"
  ]
}

# === Plex VM - Multi-homed (VLAN 20 + vmbr_storage) ===

module "plex" {
  source = "../../modules/proxmox-vm"

  name        = "pms-prod-cz-01"
  vmid        = 1000
  target_node = "pve-prod-cz-loki"
  description = "Plex Media Server - Multi-homed (Production VLAN + Storage Bridge), GPU Passthrough"

  # Resources
  cores   = 10
  sockets = 1
  memory  = 24576 # 24GB

  # Storage
  disks = [
    {
      datastore_id = "local-ssd01"
      interface    = "scsi0"
      size         = 200
      cache        = "writethrough"
      discard      = true
      iothread     = true
      ssd          = true
    }
  ]

  # Multi-homed Network
  network_interfaces = [
    # net0: Production VLAN (External Access)
    {
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = 20 # VLAN 20: Production
    },
    # net1: Storage network (Media access from TrueNAS)
    {
      model    = "virtio"
      bridge   = "vmbr_storage"
      vlan_tag = null
    }
  ]

  ip_address = "10.0.20.30/24"
  gateway    = "10.0.20.1"

  start_on_boot      = true
  qemu_agent_enabled = true

  tags = [
    "production",
    "ubuntu",
    "media",
    "plex",
    "gpu:quadro-p2200",
    "vlan:20",
    "multi-homed",
    "ansible:plex"
  ]
}

# === arr-stack VM - Multi-homed (VLAN 30 + vmbr_storage) ===

module "arr_stack" {
  source = "../../modules/proxmox-vm"

  name        = "the-arr-stack-prod-01"
  vmid        = 1100
  target_node = "pve-prod-cz-loki"
  description = "Sonarr, Radarr, etc. - Multi-homed (Compute VLAN + Storage Bridge)"

  cores  = 8
  memory = 8192

  # Storage
  disks = [
    {
      datastore_id = "local-hdd01"
      interface    = "scsi0"
      size         = 244
      discard      = true
      iothread     = true
      ssd          = false
    }
  ]

  network_interfaces = [
    # net0: Compute VLAN (Internet access, Reverse Proxy)
    {
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = 30
    },
    # net1: Storage network (Download/move to TrueNAS)
    {
      model    = "virtio"
      bridge   = "vmbr_storage"
      vlan_tag = null
    }
  ]

  ip_address = "10.0.30.90/24"
  gateway    = "10.0.30.1"

  start_on_boot      = true
  qemu_agent_enabled = true

  tags = [
    "production",
    "ubuntu",
    "media",
    "arr-stack",
    "vlan:30",
    "multi-homed",
    "ansible:arr-stack"
  ]
}

# === Nextcloud VM - Single-homed (VLAN 20) ===

module "nextcloud" {
  source = "../../modules/proxmox-vm"

  name        = "nextcloud-prod-cz-01"
  vmid        = 8000
  target_node = "pve-prod-cz-loki"
  description = "Nextcloud File Sync & Collaboration - Production VLAN"

  cores  = 12
  memory = 8192

  # Storage
  disks = [
    {
      datastore_id = "local-ssd01"
      interface    = "scsi0"
      size         = 128
      cache        = "writeback"
      discard      = true
      iothread     = true
      ssd          = true
    },
    {
      datastore_id = "local-hdd01"
      interface    = "scsi1"
      size         = 1000
      cache        = "writeback"
      discard      = true
      iothread     = true
      ssd          = false
      backup       = false
    }
  ]

  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = 20 # Production VLAN
    }
  ]

  ip_address = "10.0.20.70/24"
  gateway    = "10.0.20.1"

  start_on_boot      = true
  qemu_agent_enabled = true

  tags = [
    "production",
    "ubuntu",
    "collaboration",
    "nextcloud",
    "vlan:20",
    "ansible:nextcloud"
  ]
}

# === docker-prod VM - Single-homed (VLAN 30) ===

module "docker_prod" {
  source = "../../modules/proxmox-vm"

  name        = "docker-prod-cz-01"
  vmid        = 2000
  target_node = "pve-prod-cz-loki"
  description = "Docker Host - General Purpose Workloads (Compute VLAN)"

  cores  = 12
  memory = 12288

  # Storage
  disks = [
    {
      datastore_id = "local-hdd01"
      interface    = "scsi0"
      size         = 180
      discard      = true
      iothread     = true
      ssd          = false
    }
  ]

  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = 30 # Compute VLAN
    }
  ]

  ip_address = "10.0.30.40/24"
  gateway    = "10.0.30.1"

  start_on_boot      = true
  qemu_agent_enabled = true

  tags = [
    "production",
    "ubuntu",
    "docker",
    "vlan:30",
    "ansible:docker-host"
  ]
}
