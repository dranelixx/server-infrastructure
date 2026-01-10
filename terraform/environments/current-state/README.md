# Current State Environment

## Overview

This Terraform environment represents the **current infrastructure state** before the HP Switch and VLAN migration:

- **Switch**: Dell PowerConnect 2824 (no VLAN support)
- **Network**: Flat network on 10.0.1.0/24
- **VMs**: Single-NIC configuration, all on vmbr0

## Purpose

1. **Documentation**: Infrastructure-as-Code representation of current state
2. **Import Existing VMs**: Bring current VMs under Terraform management
3. **Drift Detection**: Monitor manual changes via `terraform plan`
4. **Migration Baseline**: Compare against target-state for migration validation

## Network Configuration

| Component   | Configuration                 |
| ----------- | ----------------------------- |
| **Switch**  | Dell PowerConnect 2824 (Flat) |
| **Subnet**  | 10.0.1.0/24                   |
| **Gateway** | 10.0.1.1 (pfSense Thor)       |
| **VLANs**   | None (flat network)           |
| **Bridge**  | vmbr0 (no VLAN tagging)       |

## Infrastructure Overview

### VMs in Current State

#### Media Infrastructure

| VM Name               | VMID | Purpose                            | vCPU | RAM   | Disk | Storage   | IP           |
| --------------------- | ---- | ---------------------------------- | ---- | ----- | ---- | --------- | ------------ |
| pms-prod-cz-01        | 1000 | Plex Media Server (4K Transcoding) | 6    | 20 GB | 100G | local-zfs | 10.0.1.30/24 |
| the-arr-stack-prod-01 | 1100 | Sonarr/Radarr/Lidarr Stack         | 4    | 8 GB  | 64G  | local-zfs | 10.0.1.90/24 |

#### Infrastructure Services

| VM Name            | VMID | Purpose                       | vCPU | RAM   | Disk | Storage   | IP           |
| ------------------ | ---- | ----------------------------- | ---- | ----- | ---- | --------- | ------------ |
| truenas-prod-cz-01 | 4000 | NAS Storage (ZFS, NFS/SMB)    | 6    | 32 GB | 100G | local-zfs | 10.0.1.20/24 |
| docker-prod-cz-01  | 2000 | Docker Host (Multiple Stacks) | 6    | 12 GB | 128G | local-zfs | 10.0.1.50/24 |

#### Cloud Services

| VM Name              | VMID | Purpose                                        | vCPU | RAM   | Disk | Storage   | IP            |
| -------------------- | ---- | ---------------------------------------------- | ---- | ----- | ---- | --------- | ------------- |
| nextcloud-prod-cz-01 | 8000 | Nextcloud Instance (File Sync & Collaboration) | 12   | 16 GB | 100G | local-zfs | 10.0.1.100/24 |

**Total VM Resources**: 34 vCPUs, 88 GB RAM

### LXC Containers in Current State

#### Monitoring Infrastructure

| Container Name        | VMID | Purpose               | Cores | RAM    | Disk | Storage     |
| --------------------- | ---- | --------------------- | ----- | ------ | ---- | ----------- |
| prometheus-prod-cz-01 | 3000 | Prometheus Monitoring | 2     | 512 MB | 4G   | local-ssd01 |
| influxdbv2-prod-cz-01 | 3002 | Time-Series Database  | 2     | 3 GB   | 8G   | local-ssd01 |

#### Security Infrastructure

| Container Name   | VMID | Purpose                              | Cores | RAM  | Disk | Storage   |
| ---------------- | ---- | ------------------------------------ | ----- | ---- | ---- | --------- |
| vault-prod-cz-01 | 3100 | HashiCorp Vault (Secrets Management) | 2     | 2 GB | 16G  | local-zfs |

#### Pterodactyl Game Panel

| Container Name           | VMID | Purpose              | Cores | RAM   | Disk | Storage     |
| ------------------------ | ---- | -------------------- | ----- | ----- | ---- | ----------- |
| ptero-panel-prod-cz-01   | 5000 | Panel (Management)   | 2     | 1 GB  | 8G   | local-zfs   |
| ptero-wings-prod-cz-01   | 5001 | Wings (Game Servers) | 24    | 32 GB | 200G | local-hdd01 |
| ptero-mariadb-prod-cz-01 | 5050 | MariaDB Database     | 2     | 1 GB  | 28G  | local-ssd01 |

#### Development Containers (Stopped)

| Container Name          | VMID | Purpose              | Cores | RAM  | Disk | Storage   |
| ----------------------- | ---- | -------------------- | ----- | ---- | ---- | --------- |
| ptero-wings-devel-cz-01 | 5998 | Wings Development    | 4     | 4 GB | 12G  | local-zfs |
| ptero-panel-devel-cz-01 | 5999 | Panel Development    | 4     | 4 GB | 8G   | local-zfs |
| ptero-panel-devel-02    | 6103 | Panel Development #2 | 4     | 4 GB | 22G  | local     |

#### IT Infrastructure

| Container Name    | VMID | Purpose       | Cores | RAM  | Disk | Storage   |
| ----------------- | ---- | ------------- | ----- | ---- | ---- | --------- |
| netbox-prod-cz-01 | 6000 | IPAM and DCIM | 2     | 3 GB | 16G  | local-zfs |

#### Productivity

| Container Name       | VMID | Purpose                 | Cores | RAM  | Disk | Storage     |
| -------------------- | ---- | ----------------------- | ----- | ---- | ---- | ----------- |
| trilium-prod-cz-01   | 6100 | Personal Knowledge Base | 1     | 1 GB | 8G   | local-zfs   |
| syncthing-prod-cz-01 | 6101 | File Synchronization    | 2     | 2 GB | 50G  | local-hdd01 |
| vscode-prod-cz-01    | 6102 | VS Code Server          | 8     | 8 GB | 20G  | local-ssd01 |

#### CI/CD Infrastructure

| Container Name           | VMID | Purpose                           | Cores | RAM  | Disk | Storage   |
| ------------------------ | ---- | --------------------------------- | ----- | ---- | ---- | --------- |
| github-runner-prod-cz-01 | 6200 | GitHub Actions Self-Hosted Runner | 2     | 2 GB | 20G  | local-zfs |

#### Logging

| Container Name     | VMID | Purpose             | Cores | RAM   | Disk | Storage     |
| ------------------ | ---- | ------------------- | ----- | ----- | ---- | ----------- |
| graylog-prod-cz-01 | 9000 | Centralized Logging | 4     | 12 GB | 130G | local-hdd01 |

**Total LXC Resources**: 43 vCPUs, 57.5 GB RAM (running) + 22 vCPUs, 22 GB RAM (stopped)

**Grand Total Infrastructure**: 77 vCPUs (running) + 22 vCPUs (stopped), 145.5 GB RAM (running) + 22 GB RAM (stopped)

## Usage

### Initial Import (First Time Only)

Import existing infrastructure into Terraform state (using bpg/proxmox provider):

```bash
cd terraform/environments/current-state

# Copy credentials
cp ../../terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real credentials

# Initialize Terraform
terraform init

# Import VMs (format: node/vmid)
terraform import 'module.truenas.proxmox_virtual_environment_vm.vm' pve-prod-cz-loki/4000
terraform import 'module.pms.proxmox_virtual_environment_vm.vm' pve-prod-cz-loki/1000
terraform import 'module.arr_stack.proxmox_virtual_environment_vm.vm' pve-prod-cz-loki/1100
terraform import 'module.docker_prod.proxmox_virtual_environment_vm.vm' pve-prod-cz-loki/2000
terraform import 'module.nextcloud.proxmox_virtual_environment_vm.vm' pve-prod-cz-loki/8000

# Import LXCs (format: node/vmid)
terraform import 'module.prometheus.proxmox_virtual_environment_container.container' pve-prod-cz-loki/3000
terraform import 'module.influxdbv2.proxmox_virtual_environment_container.container' pve-prod-cz-loki/3002
terraform import 'module.vault.proxmox_virtual_environment_container.container' pve-prod-cz-loki/3100
terraform import 'module.ptero_panel.proxmox_virtual_environment_container.container' pve-prod-cz-loki/5000
terraform import 'module.ptero_wings.proxmox_virtual_environment_container.container' pve-prod-cz-loki/5001
terraform import 'module.ptero_mariadb.proxmox_virtual_environment_container.container' pve-prod-cz-loki/5050
terraform import 'module.ptero_wings_devel.proxmox_virtual_environment_container.container' pve-prod-cz-loki/5998
terraform import 'module.ptero_panel_devel.proxmox_virtual_environment_container.container' pve-prod-cz-loki/5999
terraform import 'module.netbox.proxmox_virtual_environment_container.container' pve-prod-cz-loki/6000
terraform import 'module.trilium.proxmox_virtual_environment_container.container' pve-prod-cz-loki/6100
terraform import 'module.syncthing.proxmox_virtual_environment_container.container' pve-prod-cz-loki/6101
terraform import 'module.vscode.proxmox_virtual_environment_container.container' pve-prod-cz-loki/6102
terraform import 'module.ptero_panel_devel_02.proxmox_virtual_environment_container.container' pve-prod-cz-loki/6103
terraform import 'module.github_runner.proxmox_virtual_environment_container.container' pve-prod-cz-loki/6200
terraform import 'module.graylog.proxmox_virtual_environment_container.container' pve-prod-cz-loki/9000

# Verify state
terraform plan  # Should show minimal changes (timeouts, etc.)
```

### Daily Operations

```bash
# Check for drift (manual changes)
terraform plan

# Generate Ansible inventory
terraform output -json vm_inventory > ../../../ansible/inventory/current_state.json

# View infrastructure summary
terraform output infrastructure_summary
```

## Drift Detection

Set up automated drift detection via GitHub Actions (see `.github/workflows/terraform-drift.yml`):

- **Schedule**: Daily at 06:00 UTC
- **Trigger**: Manual or on-push to `main`
- **Alert**: Slack/Email if drift detected

## Migration to Target State

**Before migration**:

1. Verify current-state matches reality: `terraform plan` → "No changes"
2. Review target-state configuration
3. Create backup: `ansible-playbook playbooks/backup_vms.yml`

**After migration**:

1. Update current-state to match new reality (becomes deprecated)
2. Archive this workspace for historical reference
3. Use target-state as new source of truth

## Notes

- **Read-Only Intent**: This environment should rarely be modified (reflects existing infrastructure)
- **Import State**: All VMs/LXCs are imported (not provisioned by Terraform originally)
- **Tags**: Resources tagged with `ansible-*` for dynamic inventory filtering
- **No VLAN Support**: Dell switch limitation - all traffic on flat network
- **Helper Scripts**: Many LXCs created via Proxmox Helper Scripts - descriptions and original tags preserved via `lifecycle.ignore_changes`
