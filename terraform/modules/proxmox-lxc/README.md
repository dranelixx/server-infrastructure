# Proxmox LXC Container Module

Reusable Terraform module for creating Proxmox LXC containers using the `bpg/proxmox` provider (v0.91.0+).

## Features

- LXC container creation from templates
- CPU and memory resource configuration
- Swap space management
- Network configuration with bridge and VLAN support
- Unprivileged container support (default)
- Startup order and boot configuration
- Protection against accidental deletion
- Tags for organization and Ansible dynamic inventory

## Usage

```hcl
module "example_container" {
  source = "../../modules/proxmox-lxc"

  # General
  name        = "example-prod-cz-01"
  vmid        = 3000
  target_node = "pve-prod-cz-loki"
  description = "Example LXC Container"

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
  template_vmid = 9000 # ubuntu-22.04 template

  # Container Settings
  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  # Tags
  tags = ["production", "lxc", "monitoring", "ansible-prometheus"]
}
```

## Input Variables

### General Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | string | - | Container hostname (1-63 characters) |
| `vmid` | number | - | Proxmox Container ID (100-999999999) |
| `target_node` | string | - | Proxmox node name (e.g., "pve-prod-cz-loki") |
| `description` | string | `""` | Container description |
| `start_on_boot` | bool | `true` | Auto-start on Proxmox boot |
| `started` | bool | `true` | Start container after creation |
| `protection` | bool | `false` | Prevent accidental deletion |
| `tags` | list(string) | `[]` | Tags for organization and Ansible |

### Resource Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cores` | number | `2` | Number of CPU cores (1-256) |
| `memory` | number | `2048` | RAM in MB (16-1048576) |
| `swap` | number | `512` | Swap space in MB (0-1048576) |

### Disk Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `disk_size` | number | `20` | Root filesystem size in GB (1-10240) |
| `storage_pool` | string | `"local-zfs"` | Storage pool name |

### Network Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `bridge` | string | `"vmbr0"` | Network bridge |
| `vlan_tag` | number | `null` | VLAN ID (1-4094, null = no VLAN) |
| `firewall_enabled` | bool | `false` | Enable Proxmox firewall |

### Template Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `template_vmid` | number | `null` | Template container ID to clone from (optional) |

### Security Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `unprivileged` | bool | `true` | Run as unprivileged container (recommended) |

### Startup Configuration

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `startup_order` | number | `null` | Boot order (lower = first, null = any) |
| `startup_delay` | number | `0` | Delay in seconds after start |
| `shutdown_timeout` | number | `0` | Timeout for clean shutdown |

## Outputs

| Output | Description |
|--------|-------------|
| `vmid` | The Proxmox Container ID |
| `name` | The container hostname |
| `id` | The full Proxmox resource ID |
| `tags` | Container tags (for Ansible inventory) |
| `target_node` | Proxmox node where container is running |
| `resource_specs` | Container resource specifications (cores, memory, swap, disk_size) |
| `network_config` | Container network configuration (bridge, vlan_tag, firewall_enabled) |

## Examples

### Production Container

```hcl
module "prometheus" {
  source = "../../modules/proxmox-lxc"

  name        = "prometheus-prod-cz-01"
  vmid        = 3000
  target_node = "pve-prod-cz-loki"
  description = "Prometheus Monitoring Server"

  cores  = 2
  memory = 2048
  swap   = 512

  disk_size    = 20
  storage_pool = "local-zfs"

  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  template_vmid = 9000

  unprivileged  = true
  start_on_boot = true
  started       = true
  protection    = false

  tags = ["production", "lxc", "monitoring", "ansible-prometheus"]
}
```

### Development Container (Stopped)

```hcl
module "dev_environment" {
  source = "../../modules/proxmox-lxc"

  name        = "dev-environment-01"
  vmid        = 5999
  target_node = "pve-prod-cz-loki"
  description = "Development Environment"

  cores  = 2
  memory = 2048
  swap   = 512

  disk_size    = 20
  storage_pool = "local-zfs"

  bridge           = "vmbr0"
  vlan_tag         = null
  firewall_enabled = false

  template_vmid = 9000

  unprivileged  = true
  start_on_boot = false  # Don't auto-start
  started       = false  # Create stopped
  protection    = false

  tags = ["development", "lxc", "ansible-dev"]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.14.3 |
| proxmox (bpg/proxmox) | >= 0.91.0 |

## Notes

- This module optionally supports cloning from a pre-existing LXC template (specified via `template_vmid`)
- If `template_vmid` is `null`, the container is created without cloning (requires manual OS installation or Proxmox Helper Scripts)
- Unprivileged containers are recommended for security
- Description, console, operating_system, and clone settings are ignored in lifecycle to preserve Proxmox Helper Scripts metadata
- Tags are managed by Terraform (Helper Scripts tags should be added to Terraform config to preserve them)
- Network and initialization settings are ignored in lifecycle to allow manual modifications in Proxmox
- Tags are useful for Ansible dynamic inventory (e.g., `ansible-prometheus`)

## License

This module is maintained as part of the server-infrastructure repository.
