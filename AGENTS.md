# AGENTS.md

Guidance for AI coding assistants working in this repository.

## Project Overview

See [TODO.md](TODO.md) for current priorities and planned work.

Production-grade Infrastructure-as-Code repository for multi-location server infrastructure.
Uses Proxmox, pfSense, TrueNAS, Terraform Cloud (state), and HashiCorp Vault (secrets).

## Architecture Decision Records

Before making changes that affect architecture, consult the relevant ADRs in [docs/adr/](docs/adr/):

| ADR                                                        | Topic        | Key Decision                           |
| ---------------------------------------------------------- | ------------ | -------------------------------------- |
| [ADR-0001](docs/adr/ADR-0001-self-hosted-github-runner.md) | CI/CD Runner | Self-hosted for private network access |
| [ADR-0002](docs/adr/ADR-0002-vlan-network-segmentation.md) | Network      | VLANs 10/20/30 after HP switch install |
| [ADR-0003](docs/adr/ADR-0003-hashicorp-vault-secrets.md)   | Secrets      | Vault with AppRole, not ansible-vault  |
| [ADR-0004](docs/adr/ADR-0004-bpg-proxmox-provider.md)      | Terraform    | bpg/proxmox, not telmate               |
| [ADR-0005](docs/adr/ADR-0005-terraform-state-backend.md)   | State        | Migrating TF Cloud → S3 + MinIO        |
| [ADR-0006](docs/adr/ADR-0006-environment-separation.md)    | Environments | Separate directories, not workspaces   |
| [ADR-0007](docs/adr/ADR-0007-lxc-vs-vm-placement.md)       | Workloads    | VM for passthrough/isolation, LXC else |
| [ADR-0008](docs/adr/ADR-0008-backup-strategy.md)           | Backups      | vzdump + PBS + Borgmatic               |
| [ADR-0009](docs/adr/ADR-0009-modular-terraform.md)         | Modules      | Shared modules, versioning planned     |
| [ADR-0010](docs/adr/ADR-0010-cicd-strategy.md)             | CI/CD        | GitHub Actions, drift via Issues       |
| [ADR-0011](docs/adr/ADR-0011-server-hardening-baseline.md) | Security     | CrowdSec, SSH hardening, auditd        |
| [ADR-0012](docs/adr/ADR-0012-service-permissions-acl.md)   | Permissions  | ACLs for defense-in-depth secrets      |

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

<!-- markdownlint-disable MD033 -->
<rules>
NEVER push directly to main. ALL changes require a branch + pull request.
No exceptions, not even for single-line changes like TODO checkboxes or typo fixes.
</rules>
<!-- markdownlint-enable MD033 -->

Branch protection rules enforce:

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
