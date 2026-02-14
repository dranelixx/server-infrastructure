<!-- LAST EDITED: 2026-02-09 -->

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
  memory = 4096 # 4GB

  disks = [
    {
      datastore_id = "local-zfs"
      interface    = "scsi0"
      size         = 50
    }
  ]

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
  memory = 32768 # 32GB

  disks = [
    {
      datastore_id = "local-zfs"
      interface    = "scsi0"
      size         = 48
    },
    {
      datastore_id = "local-hdd01"
      interface    = "scsi1"
      size         = 128
    }
  ]

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

<!-- prettier-ignore-start -->
<!-- markdownlint-disable MD033 MD060 -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7.0 |
| proxmox | >= 0.91.0 |

## Providers

| Name | Version |
|------|---------|
| proxmox | >= 0.91.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_vm.vm](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| balloon\_memory | Minimum memory for ballooning (0 = disabled, >0 = minimum MB) | `number` | `0` | no |
| bios | BIOS implementation (seabios = Legacy BIOS, ovmf = UEFI) | `string` | `"seabios"` | no |
| clone\_template | Template VM ID to clone from (null = create from scratch) | `number` | `null` | no |
| cores | Number of CPU cores per socket | `number` | `2` | no |
| cpu\_limit | CPU limit (0 = unlimited, 1-128 = cores limit) | `number` | `0` | no |
| cpu\_type | CPU type (host = best performance, x86-64-v2-AES = migration-capable) | `string` | `"host"` | no |
| cpu\_units | CPU weighting for scheduler (100-500000, default: 1024) | `number` | `1024` | no |
| description | VM description (optional, e.g. URL or purpose) | `string` | `""` | no |
| disks | List of disks for the VM (multi-disk support) | <pre>list(object({<br/>    datastore_id = string           # Storage pool (e.g. "local-zfs", "local-hdd01")<br/>    interface    = string           # scsi0, scsi1, virtio0, sata0, ide0, etc.<br/>    size         = number           # Disk size in GB<br/>    file_format  = optional(string) # raw, qcow2, vmdk (default: raw)<br/>    cache        = optional(string) # none, directsync, writethrough, writeback, unsafe (default: none)<br/>    iothread     = optional(bool)   # Enable I/O thread (default: true for VirtIO)<br/>    ssd          = optional(bool)   # SSD emulation (default: false)<br/>    discard      = optional(bool)   # TRIM/Discard support (default: false)<br/>    backup       = optional(bool)   # Include in backups (default: true)<br/>  }))</pre> | `[]` | no |
| full\_clone | Full clone instead of linked clone (only relevant if clone\_template is set) | `bool` | `true` | no |
| gateway | Default gateway for Cloud-Init | `string` | `null` | no |
| hostpci\_devices | PCI devices to pass through to VM (GPU, HBA, NIC, etc.) | <pre>list(object({<br/>    device = string         # PCI address (e.g. "0000:08:00", "0000:88:00")<br/>    pcie   = optional(bool) # PCIe instead of PCI (default: true)<br/>    rombar = optional(bool) # Enable option ROM (default: true)<br/>    xvga   = optional(bool) # Primary GPU (default: false)<br/>  }))</pre> | `[]` | no |
| ip\_address | Static IP address for Cloud-Init (CIDR, e.g. '10.0.30.20/24', null = no Cloud-Init) | `string` | `null` | no |
| keyboard\_layout | Keyboard layout for VM console (de, en-us, fr, etc.) | `string` | `"de"` | no |
| machine | VM machine type (null = i440FX, q35 = modern PCIe chipset) | `string` | `null` | no |
| memory | RAM in MB (dedicated memory) | `number` | `2048` | no |
| name | VM hostname (must be unique in Proxmox cluster) | `string` | n/a | yes |
| network\_interfaces | List of network interfaces for multi-NIC support | <pre>list(object({<br/>    model            = string           # virtio, e1000, e1000e, rtl8139, vmxnet3<br/>    bridge           = string           # vmbr0, vmbr1, vmbr_storage, etc.<br/>    vlan_tag         = optional(number) # VLAN ID (10, 20, 30, or null)<br/>    firewall_enabled = optional(bool)   # Enable Proxmox firewall (default: false)<br/>    mac_address      = optional(string) # Custom MAC address (optional)<br/>    mtu              = optional(number) # MTU size (1 = bridge MTU, standard: 1500)<br/>    rate_limit       = optional(number) # Bandwidth limit in MB/s (0 = unlimited)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "bridge": "vmbr0",<br/>    "firewall_enabled": false,<br/>    "model": "virtio",<br/>    "vlan_tag": null<br/>  }<br/>]</pre> | no |
| numa\_enabled | Enable NUMA (Non-Uniform Memory Access) | `bool` | `false` | no |
| os\_type | Guest operating system type (l26 = Linux 2.6+, l24 = Linux 2.4, win11 = Windows 11, etc.) | `string` | `"l26"` | no |
| protection | Enable VM protection (prevents accidental deletion) | `bool` | `false` | no |
| qemu\_agent\_enabled | Enable QEMU guest agent (requires qemu-guest-agent in VM) | `bool` | `true` | no |
| scsi\_hardware | SCSI controller type (virtio-scsi-single, virtio-scsi-pci, lsi, lsi53c810, megasas, pvscsi) | `string` | `"virtio-scsi-single"` | no |
| shutdown\_timeout | Timeout in seconds for clean shutdown (0 = default) | `number` | `0` | no |
| sockets | Number of CPU sockets | `number` | `1` | no |
| start\_on\_boot | Start VM automatically when Proxmox boots | `bool` | `true` | no |
| startup\_delay | Delay in seconds after VM start (0 = default) | `number` | `0` | no |
| startup\_order | Boot order (lower numbers start first, null = any) | `number` | `null` | no |
| tags | Tags for organization and Ansible dynamic inventory (e.g. ['production', 'ubuntu', 'vlan:30']) | `list(string)` | `[]` | no |
| target\_node | Proxmox node where the VM should run (e.g. 'pve-prod-cz-loki') | `string` | n/a | yes |
| vmid | Proxmox VM ID (100-999999999) | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | The full Proxmox resource ID |
| ipv4\_address | The primary IPv4 address (from static config or QEMU agent) |
| name | The VM name |
| network\_interfaces | Network interfaces configuration |
| resource\_specs | VM resource specifications |
| tags | VM tags (for Ansible inventory) |
| target\_node | Proxmox node where VM is running |
| vmid | The Proxmox VM ID |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable MD033 MD060 -->
<!-- prettier-ignore-end -->

## Examples

See the `examples/` directory for more usage patterns:

- Single-homed VM (basic)
- Multi-homed VM (storage network)
- GPU passthrough VM
- High-availability VM
