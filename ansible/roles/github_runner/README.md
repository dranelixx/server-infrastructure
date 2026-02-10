<!-- LAST EDITED: 2026-02-10 -->

# GitHub Actions Runner Role

Ansible role to install and configure a GitHub Actions self-hosted runner on Ubuntu systems.

## Purpose

This role sets up a production-ready GitHub Actions self-hosted runner with:

- GitHub Actions Runner (latest version)
- Terraform (for IaC workflows)
- TFLint (for Terraform linting)
- Systemd service for automatic startup
- Dedicated runner user with appropriate permissions

## Requirements

- Ubuntu 20.04 or newer
- x86_64 architecture
- Network access to GitHub API
- Network access to Proxmox API (<PROXMOX_HOST>:8006)
- SSH access with sudo privileges

## Role Variables

### GitHub Runner Configuration

```yaml
github_runner_version: "latest" # GitHub runner version (or specific like "2.311.0")
github_runner_user: "github-runner" # System user for runner
github_runner_group: "github-runner" # System group for runner
github_runner_home: "/opt/actions-runner" # Runner installation directory
github_runner_work_dir: "{{ github_runner_home }}/_work" # Work directory for jobs

github_runner_repo_url: "https://github.com/dranelixx/server-infrastructure"
github_runner_repo_owner: "dranelixx"
github_runner_repo_name: "server-infrastructure"
```

### Terraform Configuration

```yaml
github_runner_terraform_version: "1.14.3" # Specific version or "latest"
github_runner_terraform_gpg_key_url: "https://apt.releases.hashicorp.com/gpg"
github_runner_terraform_repo_url: "https://apt.releases.hashicorp.com"
```

### TFLint Configuration

```yaml
github_runner_tflint_enabled: true # Enable/disable TFLint installation
github_runner_tflint_version: "latest" # TFLint version (or specific)
```

### Service Configuration

```yaml
github_runner_service_name: "github-runner"
github_runner_service_enabled: true
github_runner_service_state: "stopped" # Don't start until configured
```

### Network Configuration

```yaml
github_runner_proxmox_api_host: "<PROXMOX_HOST>"
github_runner_proxmox_api_port: 8006
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: github-runners
  become: false
  roles:
    - role: github_runner
      vars:
        github_runner_terraform_version: "1.14.3"
        github_runner_tflint_enabled: true
```

## Usage

### 1. Run the Playbook

```bash
cd ansible
ansible-playbook -i inventory/production playbooks/github_runner_setup.yml
```

### 2. Configure the Runner (Manual Steps)

After the playbook completes, you need to manually configure the runner:

```bash
# SSH to the container
ssh github-runner@<container-ip>

# Navigate to runner directory
cd /opt/actions-runner

# Get token from GitHub
# Go to: https://github.com/dranelixx/server-infrastructure/settings/actions/runners/new

# Configure the runner
./config.sh --url https://github.com/dranelixx/server-infrastructure --token <YOUR_TOKEN>

# Follow prompts:
# - Runner name: github-runner-prod-cz-01
# - Labels: self-hosted,Linux,X64,terraform,proxmox
# - Work folder: (press Enter for default)

# Start the service
sudo systemctl start github-runner
sudo systemctl status github-runner
```

### 3. Verify Installation

```bash
# Check service status
sudo systemctl status github-runner

# View logs
sudo journalctl -u github-runner -f

# Test manually (for debugging)
cd /opt/actions-runner
./run.sh
```

## Directory Structure

```text
github-runner/
├── defaults/
│   └── main.yml           # Default variables
├── handlers/
│   └── main.yml           # Systemd reload handler
├── tasks/
│   ├── main.yml           # Main task orchestration
│   ├── preflight.yml      # Pre-flight checks
│   ├── system.yml         # System setup (user, packages)
│   ├── terraform.yml      # Terraform installation
│   ├── tflint.yml         # TFLint installation
│   ├── runner.yml         # GitHub runner installation
│   ├── runner-config.yml  # Runner auto-registration
│   └── service.yml        # Systemd service setup + hardening override
├── templates/
│   └── github-runner.service.j2  # Systemd hardening drop-in override
└── README.md              # This file
```

## Tags

- `github-runner`: All tasks
- `preflight`: Pre-flight checks only
- `system`: System setup tasks
- `packages`: Package installation
- `user`: User creation
- `terraform`: Terraform installation
- `tflint`: TFLint installation
- `runner`: GitHub runner installation
- `service`: Systemd service configuration
- `network`: Network connectivity checks

### Tag Usage Examples

```bash
# Run only pre-flight checks
ansible-playbook playbooks/github_runner_setup.yml --tags preflight

# Install only Terraform
ansible-playbook playbooks/github_runner_setup.yml --tags terraform

# Skip TFLint installation
ansible-playbook playbooks/github_runner_setup.yml --skip-tags tflint

# Run system setup and runner installation
ansible-playbook playbooks/github_runner_setup.yml --tags system,runner
```

## Security Features

- Dedicated system user and group (no sudo group membership)
- Scoped sudo access via `/etc/sudoers.d/github-runner` (service management only)
- Systemd service hardening:
  - **Filesystem**: `NoNewPrivileges`, `PrivateTmp`, `PrivateDevices`, `ProtectSystem=strict`, `ProtectHome=read-only`
  - **Kernel**: `ProtectKernelTunables`, `ProtectKernelModules`, `ProtectKernelLogs`, `ProtectControlGroups`, `ProtectClock`,
    `ProtectHostname`
  - **Capabilities**: `CapabilityBoundingSet=` (all dropped), `RestrictRealtime`, `RestrictSUIDSGID`, `LockPersonality`,
    `RemoveIPC`, `SystemCallArchitectures=native`
  - Read-write access only to runner directories

## Troubleshooting

### Runner Service Won't Start

```bash
# Check service status
sudo systemctl status github-runner

# View detailed logs
sudo journalctl -u github-runner -xe

# Test manually
cd /opt/actions-runner
sudo -u github-runner ./run.sh
```

### Network Connectivity Issues

```bash
# Test GitHub API
curl -I https://api.github.com

# Test Proxmox API
curl -k https://<PROXMOX_HOST>:8006
```

### Permission Issues

```bash
# Verify ownership
ls -la /opt/actions-runner

# Fix if needed
sudo chown -R github-runner:github-runner /opt/actions-runner
```

### Runner Not Appearing in GitHub

1. Check that `config.sh` completed successfully
2. Verify `.runner` file exists in `/opt/actions-runner`
3. Check service is running: `sudo systemctl status github-runner`
4. View runner logs: `sudo journalctl -u github-runner -f`

## Idempotency

This role is fully idempotent:

- Packages are only installed if missing or outdated
- User and group creation is skipped if already exist
- Runner download is skipped if already installed
- Service file is only updated if changed

## Testing

```bash
# Syntax check
ansible-playbook playbooks/github_runner_setup.yml --syntax-check

# Dry run (check mode)
ansible-playbook playbooks/github_runner_setup.yml --check

# Run with verbose output
ansible-playbook playbooks/github_runner_setup.yml -vvv
```

## License

MIT

## Author

Created for server-infrastructure project
