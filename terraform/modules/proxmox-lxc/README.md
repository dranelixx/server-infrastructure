<!-- LAST EDITED: 2026-01-10 -->

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
| proxmox | 0.94.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [proxmox_virtual_environment_container.container](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_container) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bridge | Network bridge (e.g. 'vmbr0', 'vmbr1') | `string` | `"vmbr0"` | no |
| cores | Number of CPU cores | `number` | `2` | no |
| description | Container description (optional, e.g. purpose or service name) | `string` | `""` | no |
| disk\_size | Root filesystem size in GB | `number` | `20` | no |
| firewall\_enabled | Enable Proxmox firewall for this container | `bool` | `false` | no |
| memory | RAM in MB (dedicated memory) | `number` | `2048` | no |
| name | Container hostname (must be unique in Proxmox cluster) | `string` | n/a | yes |
| os\_type | Operating system type (unmanaged, debian, ubuntu, centos, fedora, opensuse, archlinux, alpine, gentoo) | `string` | `"ubuntu"` | no |
| protection | Enable container protection (prevents accidental deletion) | `bool` | `false` | no |
| root\_password | Root password for container access (optional, use SSH keys instead) | `string` | `null` | no |
| shutdown\_timeout | Timeout in seconds for clean shutdown (0 = default) | `number` | `0` | no |
| ssh\_public\_keys | List of SSH public keys for root user access (recommended) | `list(string)` | `[]` | no |
| start\_on\_boot | Start container automatically when Proxmox boots | `bool` | `true` | no |
| started | Start container after creation | `bool` | `true` | no |
| startup\_delay | Delay in seconds after container start (0 = default) | `number` | `0` | no |
| startup\_order | Boot order (lower numbers start first, null = any) | `number` | `null` | no |
| storage\_pool | Storage pool name (e.g. 'local-zfs', 'local-hdd01') | `string` | `"local-zfs"` | no |
| swap | Swap space in MB | `number` | `512` | no |
| tags | Tags for organization and Ansible dynamic inventory (e.g. ['production', 'lxc', 'monitoring']) | `list(string)` | `[]` | no |
| target\_node | Proxmox node where the container should run (e.g. 'pve-prod-cz-loki') | `string` | n/a | yes |
| template\_file\_id | OS template file ID from Proxmox storage (e.g., 'local:vztmpl/ubuntu-24.04-standard\_24.04-2\_amd64.tar.zst') | `string` | `"local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst"` | no |
| template\_vmid | Template container ID to clone from (null = create from scratch, number = clone from template) | `number` | `null` | no |
| unprivileged | Run container as unprivileged (recommended for security) | `bool` | `true` | no |
| vlan\_tag | VLAN ID (null = no VLAN tagging) | `number` | `null` | no |
| vmid | Proxmox Container ID (100-999999999) | `number` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| id | The full Proxmox resource ID |
| name | The container hostname |
| network\_config | Container network configuration |
| resource\_specs | Container resource specifications |
| tags | Container tags (for Ansible inventory) |
| target\_node | Proxmox node where container is running |
| vmid | The Proxmox Container ID |
<!-- END_TF_DOCS -->
<!-- markdownlint-enable MD033 MD060 -->
<!-- prettier-ignore-end -->

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

## Notes

- This module optionally supports cloning from a pre-existing LXC template (specified via `template_vmid`)
- If `template_vmid` is `null`, the container is created without cloning (requires manual OS installation or Proxmox
  Helper Scripts)
- Unprivileged containers are recommended for security
- Description, console, operating_system, and clone settings are ignored in lifecycle to preserve Proxmox Helper
  Scripts metadata
- Tags are managed by Terraform (Helper Scripts tags should be added to Terraform config to preserve them)
- Network and initialization settings are ignored in lifecycle to allow manual modifications in Proxmox
- Tags are useful for Ansible dynamic inventory (e.g., `ansible-prometheus`)

## License

This module is maintained as part of the server-infrastructure repository.
