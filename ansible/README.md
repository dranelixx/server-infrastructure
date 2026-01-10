# Ansible Automation

Ansible playbooks und roles für die Verwaltung der Server-Infrastruktur.

## Verzeichnisstruktur

```
ansible/
├── ansible.cfg              # Ansible-Konfiguration
├── inventory/               # Inventory-Dateien
│   └── github-runners.yml   # GitHub Runner Hosts
├── playbooks/               # Playbooks
│   └── github_runner_setup.yml  # GitHub Runner Setup
└── roles/                   # Rollen
    └── github-runner/       # GitHub Runner Rolle
        ├── defaults/        # Standard-Variablen
        ├── handlers/        # Handler
        ├── tasks/           # Aufgaben
        ├── templates/       # Templates
        └── README.md        # Rollen-Dokumentation
```

## Quick Start

### Voraussetzungen

```bash
# Ansible installieren
pip install ansible

# SSH-Zugriff auf Ziel-Hosts sicherstellen
ssh root@<RUNNER_IP>
```

### GitHub Runner Setup

1. **Inventory anpassen**:
   ```bash
   vim inventory/github-runners.yml
   # IP-Adresse des Containers anpassen
   ```

2. **Playbook ausführen**:
   ```bash
   cd ansible
   ansible-playbook playbooks/github_runner_setup.yml
   ```

3. **Runner konfigurieren** (manuelle Schritte):
   ```bash
   # SSH zum Container
   ssh github-runner@<RUNNER_IP>

   # Runner konfigurieren
   cd /opt/actions-runner
   ./config.sh --url https://github.com/dranelixx/server-infrastructure --token <TOKEN>

   # Service starten
   sudo systemctl start github-runner
   sudo systemctl status github-runner
   ```

## Verfügbare Playbooks

### GitHub Runner Setup

```bash
# Vollständige Installation
ansible-playbook playbooks/github_runner_setup.yml

# Nur Pre-Flight Checks
ansible-playbook playbooks/github_runner_setup.yml --tags preflight

# Nur Terraform installieren
ansible-playbook playbooks/github_runner_setup.yml --tags terraform

# TFLint überspringen
ansible-playbook playbooks/github_runner_setup.yml --skip-tags tflint

# Dry-Run (Test)
ansible-playbook playbooks/github_runner_setup.yml --check

# Verbose-Modus
ansible-playbook playbooks/github_runner_setup.yml -vvv
```

## Verfügbare Rollen

### github-runner

Installation und Konfiguration eines GitHub Actions Self-Hosted Runners.

**Features**:
- GitHub Actions Runner (latest)
- Terraform (konfigurierbare Version)
- TFLint (optional)
- Systemd-Service mit Auto-Start
- Security Hardening
- Pre-Flight Checks (Ubuntu-Version, Netzwerk)

**Dokumentation**: [roles/github-runner/README.md](roles/github-runner/README.md)

## Konfiguration

### ansible.cfg

Die Ansible-Konfiguration ist bereits vorkonfiguriert mit:
- YAML-Output für bessere Lesbarkeit
- Fact-Caching für Performance
- SSH-Optimierungen (Pipelining, ControlMaster)
- Logging nach `ansible.log`

### Inventory

Inventory-Dateien liegen in `inventory/`:
- `github-runners.yml`: GitHub Runner Hosts

**Format**: YAML (empfohlen) oder INI

### Variablen

Variablen können überschrieben werden:

```yaml
# In Playbook
vars:
  terraform_version: "1.8.0"
  tflint_enabled: false

# In Inventory
github_runner_prod:
  vars:
    terraform_version: "1.8.0"

# Per Command-Line
ansible-playbook playbooks/github_runner_setup.yml -e "terraform_version=1.8.0"
```

## Best Practices

### Pre-Flight Checks

Vor jeder Ausführung:

```bash
# Syntax-Check
ansible-playbook playbooks/github_runner_setup.yml --syntax-check

# Connectivity-Check
ansible all -m ping

# Dry-Run
ansible-playbook playbooks/github_runner_setup.yml --check
```

### Debugging

```bash
# Verbose-Modus (-v, -vv, -vvv, -vvvv)
ansible-playbook playbooks/github_runner_setup.yml -vvv

# Logs prüfen
tail -f ansible.log

# Einzelne Tasks ausführen
ansible-playbook playbooks/github_runner_setup.yml --start-at-task="Task Name"

# Facts sammeln
ansible all -m setup
```

### Idempotenz

Alle Rollen sind idempotent. Mehrfaches Ausführen führt nicht zu Problemen:

```bash
# Kann beliebig oft ausgeführt werden
ansible-playbook playbooks/github_runner_setup.yml
```

## Troubleshooting

### SSH-Verbindung fehlschlägt

```bash
# Connectivity testen
ansible all -m ping

# SSH-Debug
ssh -vvv root@<RUNNER_IP>

# ansible.cfg: host_key_checking deaktivieren
```

### Runner startet nicht

```bash
# Service-Status prüfen
ssh github-runner@<RUNNER_IP>
sudo systemctl status github-runner

# Logs anzeigen
sudo journalctl -u github-runner -f

# Manuell testen
cd /opt/actions-runner
./run.sh
```

### Playbook schlägt fehl

```bash
# Verbose-Modus
ansible-playbook playbooks/github_runner_setup.yml -vvv

# Einzelne Tags ausführen
ansible-playbook playbooks/github_runner_setup.yml --tags preflight

# Logs prüfen
tail -f ansible.log
```

## Tags

Alle Playbooks unterstützen Tags für selektive Ausführung:

| Tag | Beschreibung |
|-----|--------------|
| `github-runner` | Alle GitHub Runner Tasks |
| `preflight` | Pre-Flight Checks |
| `system` | System-Setup (User, Packages) |
| `packages` | Package-Installation |
| `user` | User-Erstellung |
| `terraform` | Terraform-Installation |
| `tflint` | TFLint-Installation |
| `runner` | GitHub Runner Installation |
| `service` | Systemd-Service Setup |
| `network` | Netzwerk-Checks |

## Erweitern

### Neue Rolle erstellen

```bash
cd ansible/roles
mkdir -p new-role/{defaults,handlers,tasks,templates,files}
touch new-role/{defaults,handlers,tasks}/main.yml
```

### Neues Playbook erstellen

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

Ansible-Playbooks können in CI/CD-Pipelines integriert werden:

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

## Weitere Ressourcen

- [Ansible Dokumentation](https://docs.ansible.com/)
- [Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [GitHub Runner Rolle](roles/github-runner/README.md)

## Support

Bei Problemen:
1. Pre-Flight Checks ausführen
2. Logs prüfen (`ansible.log`, `journalctl`)
3. Verbose-Modus aktivieren (`-vvv`)
4. Dokumentation konsultieren
