# AGENTS.md

Guidance for AI coding assistants working in this repository.

## Project Overview

See [TODO.md](TODO.md) for current priorities and planned work.

Production-grade Infrastructure-as-Code repository for multi-location server infrastructure.
Uses Proxmox, pfSense, TrueNAS, Terraform Cloud (state), and HashiCorp Vault (secrets).

## Common Commands

### Terraform

```bash
# Format check
terraform fmt -check -recursive

# Validate
terraform validate

# Plan (from environment directory)
cd terraform/environments/current-state  # or target-state
terraform init
terraform plan

# Apply (requires manual approval in CI/CD)
terraform apply
```

### Pre-commit Hooks

```bash
# Install
pip install pre-commit
pre-commit install

# Run all checks
pre-commit run --all-files

# Run specific hook
pre-commit run terraform_fmt --all-files
pre-commit run tflint --all-files
pre-commit run markdownlint --all-files
```

### Ansible

```bash
# From ansible/ directory
cd ansible

# Syntax check
ansible-playbook playbooks/github_runner_setup.yml --syntax-check

# Dry-run
ansible-playbook playbooks/github_runner_setup.yml --check

# Run with specific tags
ansible-playbook playbooks/github_runner_setup.yml --tags preflight
```

### GitHub Actions (via gh CLI)

```bash
# Trigger workflows manually
gh workflow run terraform-drift.yml
gh workflow run terraform-apply.yml -f environment=current-state

# View workflow status
gh run list --workflow=terraform-drift.yml
gh run view --log
```

## Architecture

### Terraform Environments

Two environments managed via Terraform Cloud workspaces for staged migration:

- **current-state**: Production infrastructure (Dell Switch, flat network) - actively deployed
- **target-state**: Prepared future state (HP Switch, VLANs 10/20/30, LACP bonding) - not yet deployed

Migration strategy: Map current-state first, then copy+edit for target-state.
Once HP switch is installed, target-state becomes production and current-state gets deprecated.

Both use the same reusable modules in `terraform/modules/`:

- `proxmox-vm`: VM provisioning with multi-NIC and VLAN support
- `proxmox-lxc`: LXC container provisioning
- `network-bridge`: Network abstraction layer

### CI/CD Pipeline

- **terraform-plan.yml**: Runs on PRs to `main`, posts plan as PR comment
- **terraform-apply.yml**: Runs on merge to `main`, requires manual approval via GitHub Environment protection
- **terraform-drift.yml**: Daily at 06:00 UTC, creates GitHub Issues on drift detection

Workflows use self-hosted runner (`github-runner-prod-cz-01`) for private Proxmox network access.

### Secrets Management

Primary: HashiCorp Vault (AppRole authentication)
Bootstrap: GitHub Secrets for Vault credentials only (`VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID`)

## Git Workflow

**Never push directly to `main`.** Branch protection rules require:

- Create a new branch for all changes
- Open a pull request
- Status checks must pass (`Plan - Current State`)
- Conversations must be resolved
- No bypass allowed

```bash
# Example workflow
git checkout -b feat/your-change
# make changes
git add .
git commit -m "feat(scope): description"
git push -u origin feat/your-change
gh pr create
```

## Code Style

### Terraform

- snake_case naming convention (enforced by TFLint)
- All variables and outputs must be documented
- Pin module sources
- Use `terraform fmt` before committing

### Commit Messages

Conventional Commits format: `type(scope): message`

- `feat(terraform):` - New feature
- `fix(ansible):` - Bug fix
- `docs(guides):` - Documentation
- `ci:` - CI/CD changes

### Markdown

- Prettier formatting (printWidth: 120)
- markdownlint rules apply
- Add `<!-- LAST EDITED: YYYY-MM-DD -->` header to docs
