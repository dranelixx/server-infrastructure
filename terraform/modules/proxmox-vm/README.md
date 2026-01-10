# Proxmox VM Module

Reusable Terraform module for creating and managing Proxmox VMs with advanced features:

- **Multi-NIC Support**: Configure up to 8 network interfaces
- **VLAN Tagging**: Per-interface VLAN configuration
- **Multi-homed VMs**: Separate production and storage networks
- **Cloud-init Integration**: Static IP configuration
- **Flexible Resource Allocation**: CPU, RAM, Disk sizing
- **Tag-based Organization**: For Ansible dynamic inventory

## Usage

### Basic VM (Single NIC)

```hcl
module "webserver" {
  source = "../../modules/proxmox-vm"

  name        = "webserver-01"
  vmid        = 200
  target_node = "pve-prod-cz-loki"

  cores  = 2
  memory = 4096  # 4GB
  disk_size = "50G"

  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = 20  # Production VLAN
    }
  ]

  ip_address = "10.0.20.50/24"
  gateway    = "10.0.20.1"

  tags = ["production", "ubuntu", "webserver"]
}
```

### Multi-homed VM (Storage + Production)

```hcl
module "truenas" {
  source = "../../modules/proxmox-vm"

  name        = "truenas-prod-cz-01"
  vmid        = 4000
  target_node = "pve-prod-cz-loki"

  cores  = 6
  memory = 32768  # 32GB
  disk_size = "100G"

  # Two network interfaces
  network_interfaces = [
    {
      model    = "virtio"
      bridge   = "vmbr0"
      vlan_tag = 30  # Compute VLAN
    },
    {
      model    = "virtio"
      bridge   = "vmbr_storage"
      vlan_tag = null  # Internal storage network
    }
  ]

  ip_address = "10.0.30.20/24"
  gateway    = "10.0.30.1"

  tags = ["production", "storage", "truenas", "multi-homed"]
}
```

## Inputs

| Name                 | Description                | Type           | Default   | Required |
| -------------------- | -------------------------- | -------------- | --------- | -------- |
| `name`               | VM name                    | `string`       | -         | yes      |
| `vmid`               | Proxmox VM ID (100-999999) | `number`       | -         | yes      |
| `target_node`        | Proxmox node name          | `string`       | -         | yes      |
| `cores`              | CPU cores                  | `number`       | `2`       | no       |
| `memory`             | Memory in MB               | `number`       | `2048`    | no       |
| `disk_size`          | Disk size (e.g., "32G")    | `string`       | `"32G"`   | no       |
| `network_interfaces` | List of network interfaces | `list(object)` | See below | no       |
| `ip_address`         | Static IP (CIDR)           | `string`       | `null`    | no       |
| `gateway`            | Default gateway            | `string`       | `null`    | no       |
| `tags`               | Tags for organization      | `list(string)` | `[]`      | no       |

### Network Interface Object

```hcl
{
  model            = "virtio"      # virtio, e1000, etc.
  bridge           = "vmbr0"       # vmbr0, vmbr_storage, etc.
  vlan_tag         = 30            # VLAN ID or null
  firewall_enabled = false         # Enable Proxmox firewall
  mac_address      = null          # Custom MAC (optional)
}
```

## Outputs

| Name                 | Description                      |
| -------------------- | -------------------------------- |
| `vmid`               | The Proxmox VM ID                |
| `name`               | The VM name                      |
| `ipv4_address`       | The primary IPv4 address         |
| `network_interfaces` | Network interfaces configuration |
| `tags`               | VM tags (for Ansible inventory)  |

## Examples

See the `examples/` directory for more usage patterns:

- Single-homed VM (basic)
- Multi-homed VM (storage network)
- GPU passthrough VM
- High-availability VM

## Requirements

- Terraform >= 1.14.3
- `bpg/proxmox` provider >= 0.91.0
- Proxmox VE >= 8.0
