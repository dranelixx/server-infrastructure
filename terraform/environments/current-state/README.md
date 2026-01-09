# Current State (IST) Environment

## Overview

This Terraform environment represents the **current infrastructure state** before the HP Switch and VLAN migration:

- **Switch**: Dell PowerConnect 2824 (no VLAN support)
- **Network**: Flat network on 10.0.1.0/24
- **VMs**: Single-NIC configuration, all on vmbr0

## Purpose

1. **Documentation**: Infrastructure-as-Code representation of IST-Zustand
2. **Import Existing VMs**: Bring current VMs under Terraform management
3. **Drift Detection**: Monitor manual changes via `terraform plan`
4. **Migration Baseline**: Compare against target-state for migration validation

## Network Configuration

| Component | Configuration |
|-----------|---------------|
| **Switch** | Dell PowerConnect 2824 (Flat) |
| **Subnet** | 10.0.1.0/24 |
| **Gateway** | 10.0.1.1 (pfSense Thor) |
| **VLANs** | None (flat network) |
| **Bridge** | vmbr0 (no VLAN tagging) |

## VMs in Current State

| VM Name | VMID | IP | vCPU | RAM | Disk | Purpose |
|---------|------|-------|------|-----|------|---------|
| truenas-prod-cz-01 | 4000 | 10.0.1.20/24 | 6 | 32 GB | 100G | NAS Storage |
| pms-prod-cz-01 | 1000 | 10.0.1.30/24 | 4 | 8 GB | 100G | Plex Media Server |
| the-arr-stack | 1100 | 10.0.1.90/24 | 4 | 8 GB | 64G | Sonarr/Radarr/Lidarr |
| docker-prod | 2000 | 10.0.1.50/24 | 4 | 16 GB | 128G | Docker Host |
| nextcloud-prod-cz-01 | 8000 | 10.0.1.100/24 | 4 | 8 GB | 100G | Nextcloud |

**Total Resources**: 22 vCPUs, 72 GB RAM

## Usage

### Initial Import (First Time Only)

Import existing VMs into Terraform state:

```bash
cd terraform/environments/current-state

# Copy credentials
cp ../../terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with real credentials

# Initialize Terraform
terraform init

# Import VMs (only needed once)
terraform import module.truenas.proxmox_vm_qemu.vm pve-prod-cz-loki/qemu/4000
terraform import module.pms.proxmox_vm_qemu.vm pve-prod-cz-loki/qemu/1000
terraform import module.arr_stack.proxmox_vm_qemu.vm pve-prod-cz-loki/qemu/1100
terraform import module.docker_prod.proxmox_vm_qemu.vm pve-prod-cz-loki/qemu/2000
terraform import module.nextcloud.proxmox_vm_qemu.vm pve-prod-cz-loki/qemu/8000

# Verify state
terraform plan  # Should show "No changes" if config matches reality
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
- **Import State**: All VMs are imported (not provisioned by Terraform originally)
- **Tags**: All VMs tagged with `current-state` for inventory filtering
- **No VLAN Support**: Dell switch limitation - all traffic on flat network

## Related Documentation

- [01 - Current State.md](../../../docs/architecture/01%20-%20Current%20State.md) - Detailed IST documentation
- [02 - Target State.md](../../../docs/architecture/02%20-%20Target%20State.md) - Migration target
- [03 - Migration Plan.md](../../../docs/architecture/03%20-%20Migration%20Plan.md) - Step-by-step migration
