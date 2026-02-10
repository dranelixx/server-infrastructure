<!-- LAST EDITED: 2026-02-10 -->

# Ansible Automation

Ansible playbooks and roles for managing the server infrastructure.

## Directory Structure

```text
ansible/
├── ansible.cfg              # Ansible configuration
├── requirements.yml         # Galaxy collection dependencies
├── inventory/               # Inventory files
│   ├── github-runners.yml   # GitHub Runner hosts
│   └── host_vars/           # Per-host variables (gitignored)
├── playbooks/               # Playbooks
│   ├── bootstrap.yml        # Host bootstrap (users, SSH hardening)
│   ├── github_runner_setup.yml  # GitHub Runner setup
│   └── templates/           # Playbook templates
│       └── authorized_keys.j2
└── roles/                   # Roles
    └── github_runner/       # GitHub Runner role
        ├── defaults/        # Default variables
        ├── handlers/        # Handlers
        ├── tasks/           # Tasks
        ├── templates/       # Templates
        └── README.md        # Role documentation
```

## Quick Start

### Prerequisites

```bash
# Install Ansible and dependencies
pip install ansible

# Install Galaxy collections
ansible-galaxy install -r requirements.yml

# Ensure python-hvac is installed (for Vault lookups)
# Arch: sudo pacman -S python-hvac
# Debian: pip install hvac

# Vault must be accessible with valid token
export VAULT_ADDR="https://vault.example.com:8443"
# Either export VAULT_TOKEN or run: vault login
```

### New Host Setup

1. **Add host to inventory** (`inventory/github-runners.yml`) with `ansible_user: root`

2. **Create host_vars** file (gitignored) with `ansible_host` and `ansible_port`

3. **Bootstrap the host** (creates users, deploys SSH keys from Vault):

   ```bash
   cd ansible

   # Phase 1: Create users
   ANSIBLE_HOST_KEY_CHECKING=false \
   ansible-playbook playbooks/bootstrap.yml --tags bootstrap \
     -i inventory/github-runners.yml -l <hostname>

   # Verify SSH access as BOTH users before continuing!
   ssh -p <port> akonopcz@<host-ip>       # sudo with password
   ssh -p <port> -i ~/.ssh/ansible_ed25519 ansible@<host-ip>  # passwordless sudo

   # Phase 2: Harden SSH (disables root, password auth, sets AllowUsers)
   ansible-playbook playbooks/bootstrap.yml --tags harden-ssh \
     -i inventory/github-runners.yml -l <hostname>
   ```

4. **Update inventory**: Change `ansible_user: root` to `ansible_user: ansible`

5. **Run role playbook** (e.g., GitHub Runner):

   ```bash
   ansible-playbook playbooks/github_runner_setup.yml \
     -i inventory/github-runners.yml -l <hostname>
   ```

## Available Playbooks

### Bootstrap (`bootstrap.yml`)

Two-phase host provisioning with user creation and SSH hardening.
Uses HashiCorp Vault for SSH keys and password hashes.

| Tag          | Description                                            |
| ------------ | ------------------------------------------------------ |
| `bootstrap`  | Phase 1: Create users, deploy SSH keys, configure sudo |
| `harden-ssh` | Phase 2: Disable root/password auth, apply ADR-0011    |

### GitHub Runner Setup (`github_runner_setup.yml`)

```bash
# Full installation
ansible-playbook playbooks/github_runner_setup.yml

# Pre-flight checks only
ansible-playbook playbooks/github_runner_setup.yml --tags preflight

# Install Terraform only
ansible-playbook playbooks/github_runner_setup.yml --tags terraform

# Skip TFLint
ansible-playbook playbooks/github_runner_setup.yml --skip-tags tflint

# Dry-run (test)
ansible-playbook playbooks/github_runner_setup.yml --check
```

## Available Roles

### github-runner

Installation and configuration of a GitHub Actions self-hosted runner.

**Features**:

- GitHub Actions Runner (latest)
- Terraform (configurable version)
- TFLint (optional)
- Systemd service with auto-start
- Security hardening
- Pre-flight checks (Ubuntu version, network)

**Documentation**: [roles/github_runner/README.md](roles/github_runner/README.md)

## Configuration

### ansible.cfg

The Ansible configuration is pre-configured with:

- Host key checking enabled (override with `ANSIBLE_HOST_KEY_CHECKING=false` for bootstrap)
- YAML output for better readability
- Fact caching in `~/.ansible/fact_cache/`
- SSH optimizations (pipelining, ControlMaster)
- Default `remote_user: ansible` (overridden per-host in inventory)
- Logging to `ansible.log`

### Inventory

Inventory files are located in `inventory/`:

- `github-runners.yml`: GitHub Runner hosts

**Format**: YAML (recommended) or INI

### Variables

Variables can be overridden:

```yaml
# In playbook
vars:
  github_runner_terraform_version: "1.14.3"
  github_runner_tflint_enabled: false

# In inventory
github_runner_prod:
  vars:
    github_runner_terraform_version: "1.14.3"

# Via command line
ansible-playbook playbooks/github_runner_setup.yml -e "github_runner_terraform_version=1.14.3"
```

## Best Practices

### Pre-Flight Checks

Before each execution:

```bash
# Syntax check
ansible-playbook playbooks/github_runner_setup.yml --syntax-check

# Connectivity check
ansible all -m ping

# Dry-run
ansible-playbook playbooks/github_runner_setup.yml --check
```

### Debugging

```bash
# Verbose mode (-v, -vv, -vvv, -vvvv)
ansible-playbook playbooks/github_runner_setup.yml -vvv

# Check logs
tail -f ansible.log

# Execute individual tasks
ansible-playbook playbooks/github_runner_setup.yml --start-at-task="Task Name"

# Gather facts
ansible all -m setup
```

### Idempotence

All roles are idempotent. Running them multiple times causes no issues:

```bash
# Can be executed repeatedly
ansible-playbook playbooks/github_runner_setup.yml
```

## Troubleshooting

### SSH connection fails

```bash
# Test connectivity
ansible all -m ping

# SSH debug
ssh -vvv -i ~/.ssh/ansible_ed25519 ansible@<RUNNER_IP>

# For new hosts (unknown host key):
ANSIBLE_HOST_KEY_CHECKING=false ansible all -m ping
```

### Runner doesn't start

```bash
# Check service status
ssh github-runner@<RUNNER_IP>
sudo systemctl status github-runner

# Show logs
sudo journalctl -u github-runner -f

# Test manually
cd /opt/actions-runner
./run.sh
```

### Playbook fails

```bash
# Verbose mode
ansible-playbook playbooks/github_runner_setup.yml -vvv

# Execute individual tags
ansible-playbook playbooks/github_runner_setup.yml --tags preflight

# Check logs
tail -f ansible.log
```

## Tags

All playbooks support tags for selective execution:

| Tag             | Description                   |
| --------------- | ----------------------------- |
| `github-runner` | All GitHub Runner tasks       |
| `preflight`     | Pre-flight checks             |
| `system`        | System setup (user, packages) |
| `packages`      | Package installation          |
| `user`          | User creation                 |
| `terraform`     | Terraform installation        |
| `tflint`        | TFLint installation           |
| `runner`        | GitHub Runner installation    |
| `service`       | Systemd service setup         |
| `network`       | Network checks                |

## Extending

### Create new role

```bash
cd ansible/roles
mkdir -p new-role/{defaults,handlers,tasks,templates,files}
touch new-role/{defaults,handlers,tasks}/main.yml
```

### Create new playbook

```bash
cd ansible/playbooks
vim new_playbook.yml
```

**Template**:

```yaml
---
- name: New Playbook
  hosts: all
  become: false
  roles:
    - role: new-role
```

## CI/CD Integration

Ansible playbooks can be integrated into CI/CD pipelines:

```yaml
# .github/workflows/ansible.yml
name: Ansible Deployment

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Ansible
        run: pip install ansible
      - name: Run Playbook
        run: |
          cd ansible
          ansible-playbook playbooks/github_runner_setup.yml
```

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [GitHub Runner Role](roles/github_runner/README.md)

## Support

For issues:

1. Run pre-flight checks
2. Check logs (`ansible.log`, `journalctl`)
3. Enable verbose mode (`-vvv`)
4. Consult documentation
