# Ansible Automation

Ansible playbooks and roles for managing the server infrastructure.

## Directory Structure

```text
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/               # Inventory files
│   └── github-runners.yml   # GitHub Runner hosts
├── playbooks/               # Playbooks
│   └── github_runner_setup.yml  # GitHub Runner setup
└── roles/                   # Roles
    └── github-runner/       # GitHub Runner role
        ├── defaults/        # Default variables
        ├── handlers/        # Handlers
        ├── tasks/           # Tasks
        ├── templates/       # Templates
        └── README.md        # Role documentation
```

## Quick Start

### Prerequisites

```bash
# Install Ansible
pip install ansible

# Ensure SSH access to target hosts
ssh root@<RUNNER_IP>
```

### GitHub Runner Setup

1. **Adjust inventory**:

   ```bash
   vim inventory/github-runners.yml
   # Adjust the container IP address
   ```

2. **Run playbook**:

   ```bash
   cd ansible
   ansible-playbook playbooks/github_runner_setup.yml
   ```

3. **Configure runner** (manual steps):

   ```bash
   # SSH to container
   ssh github-runner@<RUNNER_IP>

   # Configure runner
   cd /opt/actions-runner
   ./config.sh --url https://github.com/dranelixx/server-infrastructure --token <TOKEN>

   # Start service
   sudo systemctl start github-runner
   sudo systemctl status github-runner
   ```

## Available Playbooks

### GitHub Runner Setup

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

# Verbose mode
ansible-playbook playbooks/github_runner_setup.yml -vvv
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

**Documentation**: [roles/github-runner/README.md](roles/github-runner/README.md)

## Configuration

### ansible.cfg

The Ansible configuration is pre-configured with:

- YAML output for better readability
- Fact caching for performance
- SSH optimizations (pipelining, ControlMaster)
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
  terraform_version: "1.14.3"
  tflint_enabled: false

# In inventory
github_runner_prod:
  vars:
    terraform_version: "1.14.3"

# Via command line
ansible-playbook playbooks/github_runner_setup.yml -e "terraform_version=1.14.3"
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
ssh -vvv root@<RUNNER_IP>

# ansible.cfg: disable host_key_checking
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
  become: no
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
- [GitHub Runner Role](roles/github-runner/README.md)

## Support

For issues:

1. Run pre-flight checks
2. Check logs (`ansible.log`, `journalctl`)
3. Enable verbose mode (`-vvv`)
4. Consult documentation
