<!-- LAST EDITED: 2026-01-10 -->

# GitHub Actions Workflows for Terraform

These workflows automate Terraform operations for the Proxmox infrastructure.

## Workflows

### 1. Terraform Drift Detection (`terraform-drift.yml`)

Checks daily whether the Proxmox infrastructure deviates from the Terraform state.

**Triggers:**
- Daily at 06:00 UTC (Cron: `0 6 * * *`)
- Manually via `workflow_dispatch`
- On push to `main` (optional, for testing)

**Functions:**
- Parallel drift checks for `current-state` and `target-state`
- Automatically creates GitHub Issues when drift is detected
- Automatically closes issues when drift is resolved
- Uploads plan outputs as artifacts (30 days retention)

**Exit Codes:**
- `0` = No changes (no drift)
- `2` = Changes detected (drift present)
- `1` = Error during plan

### 2. Terraform Plan (`terraform-plan.yml`)

Runs `terraform plan` on pull requests and posts the result as a comment.

**Triggers:**
- Pull requests against `main` branch
- Only when files under `terraform/**` are changed

**Functions:**
- Runs plan for changed environments
- Posts plan output as PR comment
- Updates existing comments instead of creating new ones
- Uploads plans as artifacts (30 days retention)
- Validates Terraform format, init, and validate

### 3. Terraform Apply (`terraform-apply.yml`)

Applies Terraform changes after manual approval.

**Triggers:**
- Push to `main` branch
- Manually via `workflow_dispatch` (with environment selection)

**Functions:**
- Automatic detection of changed environments
- Environment Protection: Requires manual approval in GitHub
- Creates GitHub Issues on apply failures
- Uploads apply logs as artifacts (90 days retention)
- GitHub Actions Summary with apply details

## Setup

### 1. Configure GitHub Secrets

The following secrets must be created in the repository under `Settings > Secrets and variables > Actions`:

```bash
PROXMOX_API_ENDPOINT       # e.g. https://<PROXMOX_HOST>:8006/api2/json
PROXMOX_API_TOKEN_ID       # e.g. terraform@pve!tf-automation
PROXMOX_API_TOKEN_SECRET   # Secret of the API token
```

**Note**: This project follows a Vault-first secrets management approach. For production deployments, consider migrating secrets from GitHub Secrets to HashiCorp Vault for centralized secret management, rotation, and audit logging. GitHub Secrets serve as a bootstrap mechanism for CI/CD workflows until Vault integration is fully implemented.

### 2. Create Proxmox API Token

```bash
# On Proxmox host:
pveum role add TerraformAutomation -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit Sys.Audit Sys.Console Sys.Modify Pool.Allocate"

pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role TerraformAutomation
pveum user token add terraform@pve tf-automation --privsep 0

# Copy token ID and secret and save as GitHub Secrets
```

### 3. Configure GitHub Environment

1. Go to `Settings > Environments > New environment`
2. Name: `production`
3. Configure Protection Rules:
   - ✅ Required reviewers: Select at least 1 reviewer
   - ✅ Wait timer: Optional, e.g. 5 minutes
4. Environment Secrets: Can optionally be the same as Repository Secrets

### 4. Branch Protection Rules

Recommended branch protection for `main`:

```yaml
- Require pull request reviews (1 approval)
- Require status checks to pass:
  - Plan - Current State
  - Plan - Target State
- Require conversation resolution
- Do not allow bypassing the above settings
```

## Usage

### Normal Changes (via Pull Request)

1. Create branch: `git checkout -b feature/my-changes`
2. Make Terraform changes
3. Create pull request
4. Workflow `terraform-plan.yml` runs automatically
5. Review plan output as PR comment
6. Merge PR after approval
7. Workflow `terraform-apply.yml` runs automatically with manual approval
8. Approve in GitHub UI to execute apply

### Manual Changes

```bash
# Run drift detection manually
gh workflow run terraform-drift.yml

# Apply for specific environment
gh workflow run terraform-apply.yml -f environment=current-state
gh workflow run terraform-apply.yml -f environment=target-state
gh workflow run terraform-apply.yml -f environment=both
```

## Monitoring

### Status Badges

Add these badges to your README:

```markdown
![Terraform Drift](https://github.com/YOUR-USERNAME/server-infrastructure/actions/workflows/terraform-drift.yml/badge.svg)
![Terraform Plan](https://github.com/YOUR-USERNAME/server-infrastructure/actions/workflows/terraform-plan.yml/badge.svg)
![Terraform Apply](https://github.com/YOUR-USERNAME/server-infrastructure/actions/workflows/terraform-apply.yml/badge.svg)
```

### Notifications

Drift detection automatically creates issues with labels:
- `drift-detection` - All drift issues
- `terraform` - Terraform-related issues
- `current-state` or `target-state` - Environment-specific

Apply failures create issues with labels:
- `terraform` - Terraform-related issues
- `apply-failure` - Apply failed
- `urgent` - Requires immediate attention
- `current-state` or `target-state` - Environment-specific

## Troubleshooting

### Workflow fails: "Error: No such file or directory"

Check if the environments exist:
```bash
ls -la terraform/environments/
```

### Plan finds no changes, but apply fails

The state could be out-of-sync:
```bash
cd terraform/environments/current-state
terraform refresh
```

### Drift is continuously detected

Possible causes:
1. Manual changes in Proxmox
2. Resources exist in Proxmox but not in state
3. Provider differences (e.g. default values)

Solution:
```bash
# Update state
terraform import <resource> <id>

# Or: Accept drift and adjust state
terraform apply
```

### API token doesn't work

Check token format:
```bash
# Format: user@realm!token-id=secret
# Example: terraform@pve!tf-automation=12345678-1234-1234-1234-123456789abc
```

## Best Practices

1. **Never push directly to `main`** - Always use pull requests
2. **Review plan output** - Check what will be changed before every merge
3. **Address drift issues promptly** - Avoid manual changes
4. **Archive apply logs** - Kept for 90 days for audits
5. **Token rotation** - Renew API tokens regularly
6. **Environment protection** - Always manual approval for production

## Concurrency

- **Drift Detection**: Only one run at a time, no cancellation
- **Plan**: One run per PR, old runs are cancelled
- **Apply**: Only one run at a time, no cancellation

This prevents state locks and race conditions.

## Security

- Secrets are never output in logs
- Terraform outputs are deleted after 30/90 days
- API access only via GitHub-hosted runners (secure IP range)
- Terraform state local (or in Terraform Cloud, if configured)
- **Vault Integration**: For enhanced security, production deployments should leverage HashiCorp Vault for dynamic secret generation, automatic rotation, and comprehensive audit trails. GitHub Secrets currently serve as the interim solution during initial infrastructure setup.

## Further Documentation

- [HashiCorp Terraform Docs](https://www.terraform.io/docs)
- [bpg/proxmox Provider](https://github.com/bpg/terraform-provider-proxmox)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
