# Proxmox VM Module
# Reusable module for creating Proxmox VMs with multi-NIC and VLAN support

resource "proxmox_vm_qemu" "vm" {
  # Basic VM Configuration
  name        = var.name
  target_node = var.target_node
  vmid        = var.vmid
  desc        = var.description

  # Clone from template (if specified)
  clone      = var.clone_template
  full_clone = var.full_clone

  # CPU Configuration
  cores   = var.cores
  sockets = var.sockets
  cpu     = var.cpu_type

  # Memory Configuration (in MB)
  memory  = var.memory
  balloon = var.balloon_memory

  # Boot Configuration
  boot    = "order=scsi0"
  scsihw  = "virtio-scsi-single"
  onboot  = var.start_on_boot
  agent   = var.qemu_agent_enabled ? 1 : 0

  # Disk Configuration
  disks {
    scsi {
      scsi0 {
        disk {
          size       = var.disk_size
          storage    = var.storage_pool
          iothread   = true
          discard    = true
          emulatessd = var.emulate_ssd
        }
      }
    }
  }

  # Network Interfaces (supports multiple NICs)
  dynamic "network" {
    for_each = var.network_interfaces

    content {
      model    = network.value.model
      bridge   = network.value.bridge
      tag      = network.value.vlan_tag
      firewall = network.value.firewall_enabled
      macaddr  = try(network.value.mac_address, null)
    }
  }

  # Cloud-Init (optional, nur wenn IP konfiguriert)
  dynamic "ipconfig0" {
    for_each = var.ip_address != null ? [1] : []

    content {
      ip  = var.ip_address
      gw  = var.gateway
    }
  }

  # Tags for organization and Ansible dynamic inventory
  tags = join(",", var.tags)

  # Lifecycle Management
  lifecycle {
    ignore_changes = [
      network,  # NICs können manuell im Proxmox geändert werden
      disk,     # Disk size growth wird ignoriert
      ciuser,   # Cloud-init user changes
      sshkeys,  # SSH key changes
    ]
  }
}
