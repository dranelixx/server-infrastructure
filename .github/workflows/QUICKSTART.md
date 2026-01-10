# Terraform Workflows - Quick Start Guide

## Secrets Setup (One-time)

```bash
# 1. Create API token on Proxmox host
pveum user add terraform@pve
pveum role add TerraformAutomation -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit Sys.Audit Sys.Console Sys.Modify Pool.Allocate"
pveum aclmod / -user terraform@pve -role TerraformAutomation
pveum user token add terraform@pve tf-automation --privsep 0

# 2. In GitHub: Settings > Secrets > Actions > New repository secret
PROXMOX_API_ENDPOINT        = https://<PROXMOX_HOST>:8006/api2/json
PROXMOX_API_TOKEN_ID        = terraform@pve!tf-automation
PROXMOX_API_TOKEN_SECRET    = <secret-from-step-1>
```

**Vault-First Approach**: This project is designed with HashiCorp Vault as the primary secrets management solution. GitHub Secrets provide a bootstrap mechanism for CI/CD workflows. For production environments, migrate to Vault for:
- Dynamic secret generation
- Automatic credential rotation
- Centralized access control
- Comprehensive audit logging
- Secrets versioning and rollback

## GitHub Environment Setup

```bash
# GitHub Repository > Settings > Environments > New environment
Name: production
Protection Rules:
  ✅ Required reviewers (at least 1)
  ✅ Wait timer: 5 minutes (optional)
```

## Workflow Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-drift.yml` | Daily 06:00 UTC, manual | Drift Detection |
| `terraform-plan.yml` | Pull Request | Plan on PR |
| `terraform-apply.yml` | Push to main, manual | Apply Changes |

## Typical Workflow

```bash
# 1. Create branch
git checkout -b feature/add-vm

# 2. Make Terraform changes
vim terraform/environments/current-state/main.tf

# 3. Test locally (optional)
cd terraform/environments/current-state
terraform init
terraform plan

# 4. Commit and push
git add .
git commit -m "feat: Add new VM to current-state"
git push origin feature/add-vm

# 5. Create pull request
gh pr create --title "Add new VM" --body "..."

# 6. Wait for plan workflow
# Plan output is automatically posted as PR comment

# 7. Review and merge PR
gh pr merge --squash

# 8. Apply workflow waits for manual approval
# GitHub UI > Actions > Terraform Apply > Review deployments > Approve

# 9. Apply runs automatically after approval
```

## Manual Workflow Execution

```bash
# Start drift detection manually
gh workflow run terraform-drift.yml

# Apply for specific environment
gh workflow run terraform-apply.yml -f environment=current-state
gh workflow run terraform-apply.yml -f environment=target-state
gh workflow run terraform-apply.yml -f environment=both

# Check workflow status
gh run list --workflow=terraform-drift.yml
gh run watch  # Watch current run
```

## Understanding Drift Detection

```yaml
Exit Code 0: ✅ No drift - Infrastructure = State
Exit Code 2: ⚠️  Drift detected - Issue will be created
Exit Code 1: ❌ Error - Workflow failed
```

```bash
# Fix drift
cd terraform/environments/current-state

# Option 1: Update state (for manual changes)
terraform refresh
terraform apply

# Option 2: Align Proxmox to state (rollback)
terraform apply

# Option 3: Import resource (if not in state)
terraform import module.vm_name.proxmox_vm_qemu.this 100
```

## Common Commands

```bash
# Run plan locally (before PR)
cd terraform/environments/current-state
terraform plan

# Show workflow logs
gh run view --log

# Download artifacts
gh run download <run-id>

# Show issues with drift label
gh issue list --label drift-detection

# Show apply-failure issues
gh issue list --label apply-failure
```

## Troubleshooting

### Problem: Plan fails with "Error acquiring the state lock"

```bash
# Solution: Remove lock manually (only if safe!)
terraform force-unlock <lock-id>
```

### Problem: Apply fails with "resource already exists"

```bash
# Solution: Import resource into state
terraform import <resource-address> <proxmox-id>

# Example:
terraform import module.truenas.proxmox_vm_qemu.this 4000
```

### Problem: Drift is continuously detected

```bash
# Find cause
terraform plan -out=tfplan
terraform show tfplan

# Common causes:
# 1. Provider default values
# 2. Manual changes in Proxmox
# 3. Timestamp changes (ignore with lifecycle)
```

### Problem: API token doesn't work

```bash
# Test token
curl -k -H "Authorization: PVEAPIToken=terraform@pve!tf-automation=<SECRET>" \
  https://<PROXMOX_HOST>:8006/api2/json/nodes

# Check format (must be exactly like this):
# user@realm!token-id=secret
```

## Status Badges

```markdown
![Drift Detection](https://github.com/YOUR-USERNAME/server-infrastructure/actions/workflows/terraform-drift.yml/badge.svg)
![Terraform Plan](https://github.com/YOUR-USERNAME/server-infrastructure/actions/workflows/terraform-plan.yml/badge.svg)
![Terraform Apply](https://github.com/YOUR-USERNAME/server-infrastructure/actions/workflows/terraform-apply.yml/badge.svg)
```

## Best Practices

1. Always use PR-based workflow (never push directly to main)
2. Review plan output before merge
3. Address drift issues promptly
4. Document manual Proxmox changes
5. Rotate API tokens regularly (or use Vault for automatic rotation)
6. Keep apply logs for audits (90 days)
7. Don't bypass environment protection
8. Migrate to Vault for production secret management

## Useful Aliases

```bash
# In ~/.bashrc or ~/.zshrc
alias tf='terraform'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfi='terraform init'
alias tfv='terraform validate'
alias tff='terraform fmt'

# GitHub CLI
alias ghw='gh workflow run'
alias ghr='gh run list'
alias ghv='gh run view'
```

## Emergency Procedure

For critical apply failures:

```bash
# 1. Cancel workflow
gh run cancel <run-id>

# 2. Check state
cd terraform/environments/<environment>
terraform show

# 3. Create backup
terraform state pull > backup-$(date +%Y%m%d-%H%M%S).tfstate

# 4. Fix manually
terraform console
# or
vim main.tf

# 5. Test plan locally
terraform plan

# 6. Apply locally (if urgent)
terraform apply
```

## Support

- GitHub Issues: For bugs and feature requests
- Drift-Detection Issues: Automatically created on drift
- Apply-Failure Issues: Automatically created on errors
- Workflow Documentation: `.github/workflows/README.md`
