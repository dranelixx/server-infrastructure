<!-- LAST EDITED: 2026-02-11 -->

# Hetzner Environment

## Overview

This Terraform environment maps **existing Hetzner Cloud infrastructure** into Terraform management. It uses declarative
`import {}` blocks (Terraform 1.5+) to bring resources under state control without reprovisioning.

**Purpose:**

1. **Documentation**: Infrastructure-as-Code representation of Hetzner resources
2. **Import Existing Resources**: Bring VPS, Storage Box, and Firewall under Terraform management
3. **Drift Detection**: Monitor manual changes via `terraform plan`
4. **Protection**: `prevent_destroy` + `delete_protection` guard against accidental deletion

## Resources

| Resource    | Type   | Name                       | Location | ID        | Notes                           |
| ----------- | ------ | -------------------------- | -------- | --------- | ------------------------------- |
| VPS         | `cx23` | `debian-prod-fsn1-dc14-01` | `fsn1`   | 115629222 | delete + rebuild protection     |
| Storage Box | `bx21` | `backup-storage-box-01`    | `fsn1`   | 463672    | delete protection, ignore pw    |
| Firewall    | -      | `firewall-1`               | -        | 10302319  | 5 inbound rules, applied to VPS |

## Firewall Rules (Inbound)

| Rule    | Protocol | Port | Source          |
| ------- | -------- | ---- | --------------- |
| ICMP    | ICMP     | -    | Any IPv4 / IPv6 |
| SSH     | TCP      | 22   | Any IPv4 / IPv6 |
| HTTP    | TCP      | 80   | Any IPv4 / IPv6 |
| HTTPS   | TCP      | 443  | Any IPv4 / IPv6 |
| Coolify | TCP      | 8000 | Any IPv4 / IPv6 |

## Secrets Management

### Vault Paths

| Variable                      | Vault Path                                     | Field       |
| ----------------------------- | ---------------------------------------------- | ----------- |
| `TF_VAR_hcloud_token`         | `secret/prod/infrastructure/hetzner`           | `api_token` |
| `TF_VAR_storage_box_password` | `secret/shared/backup/hetzner-storagebox-main` | `password`  |

### Vault Setup (First Time)

```bash
# Store Hetzner API token in Vault
vault kv put secret/prod/infrastructure/hetzner \
  api_token="<YOUR_HCLOUD_API_TOKEN>"

# Storage Box password (may already exist from Borgmatic setup)
vault kv put secret/shared/backup/hetzner-storagebox-main \
  password="<YOUR_STORAGE_BOX_PASSWORD>"
```

### Loading Credentials

```bash
# Option A: direnv (recommended) - automatically loads .envrc
cd terraform/environments/hetzner
direnv allow

# Option B: Manual export
export TF_VAR_hcloud_token=$(vault kv get -field=api_token secret/prod/infrastructure/hetzner)
export TF_VAR_storage_box_password=$(vault kv get -field=password secret/shared/backup/hetzner-storagebox-main)
```

## Usage

### Initial Import (First Time Only)

1. **Run import**:

```bash
cd terraform/environments/hetzner

# Initialize Terraform (downloads hcloud provider)
terraform init

# Preview import - shows what will be imported and any config drift
terraform plan

# Apply import - brings resources into state
terraform apply
```

1. **Remove import blocks** from `main.tf` after successful import (they are one-time use).

2. **Verify clean state**:

```bash
terraform plan  # Should show "No changes"
```

### Daily Operations

```bash
# Check for drift (manual changes outside Terraform)
terraform plan

# View VPS details
terraform output server_info

# View Storage Box details
terraform output storage_box_info

# View firewall rules
terraform output firewall_info

# View infrastructure summary
terraform output infrastructure_summary
```

## Notes

- **Read-Only Intent**: This environment should rarely be modified (reflects existing infrastructure)
- **Import State**: All resources are imported (not originally provisioned by Terraform)
- **delete_protection**: Enabled on both VPS and Storage Box via Hetzner API - must be disabled in Hetzner Console
  before Terraform can destroy resources
- **prevent_destroy**: Terraform-side lifecycle rule that blocks `terraform destroy` even if delete_protection is off
- **rebuild_protection**: Must match `delete_protection` on VPS (Hetzner API constraint)
- **ignore_changes on Storage Box**: `ssh_keys` triggers ForceNew since provider v1.58.0 (would destroy and recreate
  the Storage Box = data loss). `password` is ignored to prevent unintended changes on the imported resource.
