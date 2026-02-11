<!-- LAST EDITED: 2026-02-11 -->

# ADR-0014: Ansible Common Role & Bootstrap Strategy

## Status

Draft

## Context

The infrastructure spans ~20 Proxmox hosts (5 VMs, 15 LXCs), plus external hosts at Hetzner and Netcup.
All hosts need a consistent security baseline (ADR-0011), monitoring, and user management. Currently,
only the GitHub runner has an Ansible role. Manual configuration across 20+ hosts is error-prone and
creates drift.

Key requirements:

- Consistent security baseline across all hosts (ADR-0011)
- Repeatable, idempotent configuration management
- Clear separation between one-time provisioning and ongoing management
- All hosts Debian/Ubuntu (Alpine on prometheus-prod-cz-01 to be migrated)

## Decision

### Two-Layer Approach: Provisioning + Common Role

#### Day 0 Provisioning (one-time, per host)

Users are created during host provisioning — not by a bootstrap playbook. The method depends on host type:

| Host Type    | Method                                           | User Creation              |
| ------------ | ------------------------------------------------ | -------------------------- |
| Proxmox VMs  | Cloud-Init image + cloud-init YAML via Terraform | Users + keys on first boot |
| Proxmox LXCs | Custom LXC template (based on Ubuntu)            | Users baked into template  |
| Hetzner VPS  | Cloud-Init via `user_data`                       | Users + keys on first boot |
| Netcup VPS   | Manual setup (no cloud-init support)             | Create users by hand       |

**Users on every host:**

- `akonopcz` — Interactive admin (SSH keys from Vault, sudo WITH password, member of `ssh-users`)
- `ansible` — Automation user (SSH key from Vault, passwordless sudo, member of `ssh-users`)
- `root` — Disabled for SSH access (`PermitRootLogin no`)

**Cloud-Init (VMs + Hetzner):** Terraform reads SSH keys from Vault at apply time, passes them via
cloud-config YAML. No secrets baked into images — keys stay rotatable without rebuilding.
Wait for `cloud-init status --wait` before running Ansible (Terraform provisioner or `depends_on`).

**Custom LXC Template:** Standard Ubuntu template with pre-configured users, groups (`ssh-users`),
sudo rules, and SSH keys. For key rotation on existing LXCs, the Common Role updates
`authorized_keys` from Vault. Only new LXCs created between key rotation and template rebuild
would need attention — acceptable risk at this fleet size (~15 LXCs).

**Bootstrap playbook** remains in the repository as reference/documentation and fallback for
edge cases (Netcup, manually provisioned hosts). Not part of the standard provisioning flow.

#### Common Role (Day 1+ — repeatable, all hosts)

Runs as `ansible` user. Applies the full configuration baseline. Idempotent, safe to run repeatedly.

```text
roles/common/
├── defaults/main.yml
├── handlers/main.yml
├── tasks/
│   ├── main.yml           # Orchestration via tags
│   ├── packages.yml        # Base packages, unattended-upgrades
│   ├── ssh.yml             # Full ADR-0011 SSH config (sshd_config.d/hardening.conf)
│   ├── security.yml        # CrowdSec, auditd rules, sysctl hardening
│   ├── sudo.yml            # Sudo logging, timeouts, secure_path
│   ├── monitoring.yml      # node_exporter (+ optional promtail)
│   ├── time.yml            # chrony/systemd-timesyncd
│   └── banner.yml          # Legal banner (/etc/issue.net)
└── templates/
    ├── sshd-hardening.conf.j2
    ├── sysctl-hardening.conf.j2
    ├── auditd-hardening.rules.j2
    └── ...
```

### Task Breakdown

#### packages.yml

Base packages for all hosts:

- `curl`, `jq`, `btop`, `wget`, `gnupg`, `ca-certificates`
- `unattended-upgrades` (security updates auto, reboots manual)
- `qemu-guest-agent` (VMs only, conditional on `ansible_virtualization_type != 'lxc'`)

#### ssh.yml

Manages SSH configuration as a clean two-file approach:

1. **Reset `sshd_config` to stock values** and add a comment header directing edits to
   `sshd_config.d/hardening.conf`. This ensures package updates to `sshd_config` don't conflict.
2. **Deploy `/etc/ssh/sshd_config.d/hardening.conf`** as a template — single source of truth for
   all custom SSH settings.
3. **Clean up legacy bootstrap directives** from `sshd_config` (remove `lineinfile` entries from
   Phase 2 via `state: absent`) to prevent dead entries that confuse debugging.
4. **Validate** with `sshd -t` before every sshd restart.

Uses `AllowGroups ssh-users` instead of `AllowUsers` — more flexible when adding users later.

Directives from ADR-0011: `LoginGraceTime`, `MaxAuthTries`, `MaxSessions`, `ClientAliveInterval`,
`X11Forwarding no`, `AllowTcpForwarding no`, `AllowAgentForwarding no`, strong ciphers, etc.

Also manages `authorized_keys` for both users (keys from Vault) — enables key rotation as a
Day 2 operation without re-provisioning hosts.

#### security.yml

**CrowdSec:**

- Install CrowdSec + firewall bouncer
- Base collections: `crowdsecurity/linux`, `crowdsecurity/sshd` (always)
- Service-specific collections via variable (e.g., `crowdsecurity/nginx`, `crowdsecurity/postfix`)
- Docker hosts: `DOCKER-USER` chain in bouncer config via `common_crowdsec_docker_host` variable
- Optional enrollment key from Vault (via `common_crowdsec_enroll` toggle)

**auditd (VMs only):**

- Install `auditd` + `audispd-plugins`
- Deploy ADR-0011 rules: sudoers, sshd_config, authorized_keys, passwd/shadow, cron, systemd
- Logrotate configuration
- Skipped on LXC containers (`when: ansible_virtualization_type != 'lxc'`) — auditd requires
  kernel-level access not available in unprivileged LXCs

**sysctl:**

- Deploy `/etc/sysctl.d/99-hardening.conf` from ADR-0011
- IP spoofing, ICMP redirects, SYN flood, source routing, martian logging
- LXC-aware: some network sysctls are ignored in unprivileged LXCs. The template includes
  conditionals to skip unsupported settings (`ansible_virtualization_type == 'lxc'`)

#### sudo.yml

- Logging: `logfile`, `log_input`, `log_output`, `iolog_dir`
- Security: `passwd_timeout=1`, `timestamp_timeout=5`, `passwd_tries=3`, `secure_path`
- Logrotate for `/var/log/sudo.log` and `/var/log/sudo-io`

#### monitoring.yml

- `node_exporter`: install, systemd unit, configurable collectors via variable
- Optional TLS/auth for node_exporter (credentials from Vault when enabled)
- `promtail`: optional (disabled by default, enable when Loki/Graylog is ready)

#### time.yml

- `chrony` or `systemd-timesyncd` for consistent time
- Critical for: Vault leases, TLS certificates, log correlation

#### banner.yml

- Legal banner from ADR-0011 to `/etc/issue.net` and `/etc/issue`

### Host-Specific Configuration via Variables

No `when: inventory_hostname == 'xxx'` in the role. Everything via variables in inventory
group_vars or host_vars:

```yaml
# group_vars/docker_hosts.yml
common_crowdsec_docker_host: true
common_crowdsec_collections:
  - crowdsecurity/nginx

# group_vars/all.yml
common_node_exporter_collectors:
  - systemd
  - processes
```

### What Does NOT Belong in Common

- **User creation** — handled by provisioning (Cloud-Init, LXC template, or manual)
- **Firewall rules** — too host-specific, comes with VLAN migration (ADR-0002)
- **Docker installation** — separate role
- **Service configuration** — separate roles (mailcow, vaultwarden, pterodactyl, etc.)

### Vault Integration

The Common role uses Vault for **optional** secrets with sensible defaults:

| Secret                     | Used When                        | Default (no Vault)            |
| -------------------------- | -------------------------------- | ----------------------------- |
| SSH keys (authorized_keys) | Always (key rotation)            | Keys from provisioning remain |
| CrowdSec enrollment key    | `common_crowdsec_enroll: true`   | Skip enrollment               |
| node_exporter TLS/auth     | `common_node_exporter_tls: true` | No TLS, local only            |

Core functionality (packages, SSH hardening config, sysctl, auditd rules, sudo, time, banner)
works without Vault access. Secret-dependent features are opt-in via variables.

### LXC vs VM Considerations

LXC containers share the host kernel, which limits certain hardening measures:

| Feature          | VMs          | LXCs (unprivileged)                         |
| ---------------- | ------------ | ------------------------------------------- |
| auditd           | Full support | Not available (needs kernel access)         |
| sysctl           | Full support | Restricted (network sysctls mostly ignored) |
| CrowdSec         | Full support | Works, but iptables needs configuration     |
| qemu-guest-agent | Required     | Not applicable                              |

The Common role uses `ansible_virtualization_type` to conditionally skip or adapt tasks for LXCs.
This affects ~75% of the fleet (15 LXCs vs 5 VMs).

### Rollout Strategy

Fleet-wide changes are deployed incrementally to limit blast radius:

```yaml
# site.yml — canary deployment pattern
- name: Deploy common role (canary)
  hosts: canary
  roles: [common]

- name: Deploy common role (fleet)
  hosts: all:!canary
  serial: 5
  max_fail_percentage: 0
  roles: [common]
```

- **Canary host** receives changes first (lowest-impact host, e.g., a test LXC)
- **`serial: 5`** processes remaining hosts in batches of 5
- **`max_fail_percentage: 0`** stops immediately on any failure (no cascading breakage)

### Drift Detection

Ansible configuration drift is detected via scheduled CI (analogous to the Terraform drift
workflow in ADR-0010):

- Scheduled GitHub Actions run: `ansible-playbook site.yml --check --diff`
- Creates a GitHub Issue when drift is detected
- Ensures manual changes are caught and corrected

## Consequences

### Positive

- Consistent baseline across all ~20+ hosts
- ADR-0011 implemented as code (not just documentation)
- Idempotent — safe to run repeatedly, detects and fixes drift
- Tag-based selective execution (`--tags ssh`, `--tags security`, etc.)
- New host provisioning: Terraform (Day 0) → Common Role (Day 1) → Service role (predictable flow)
- No bootstrap needed for Proxmox hosts (Cloud-Init/templates handle Day 0)
- LXC-aware: graceful handling of kernel-level restrictions

### Negative

- Initial effort to build and test the role (~2-3 sessions)
- All hosts must be Debian/Ubuntu (Alpine migration required for prometheus)
- CrowdSec setup has learning curve (collections, bouncer configuration)
- Custom LXC template requires occasional rebuilds (user changes, key rotation)

### Neutral

- Bootstrap playbook kept as fallback for Netcup and edge cases
- CI integration comes later (lint first, then dry-run, then auto-deploy)

## Alternatives Considered

| Alternative                     | Rejected Because                                            |
| ------------------------------- | ----------------------------------------------------------- |
| Multi-OS role (Debian + Alpine) | 90% Debian, Alpine maintenance cost not worth it for 1 host |
| All-in-one playbook (no role)   | Not reusable, not testable, doesn't scale to 20+ hosts      |
| Skip Common, only service roles | Duplicated security config in every service role            |
| Bootstrap for all hosts         | Cloud-Init/templates eliminate the chicken-and-egg problem  |
| Separate with/without Vault     | Overengineering — opt-in features with defaults are simpler |

## References

- [ADR-0011: Server Hardening Baseline](ADR-0011-server-hardening-baseline.md) — security directives
  implemented by this role
- [ADR-0003: HashiCorp Vault](ADR-0003-hashicorp-vault-secrets.md) — secrets for SSH keys, CrowdSec, monitoring
- [ADR-0013: Least-Privilege API Token](ADR-0013-least-privilege-api-token.md) — principle applied to
  user permissions

## Changelog

| Date       | Change                                                                       |
| ---------- | ---------------------------------------------------------------------------- |
| 2026-02-10 | Initial draft                                                                |
| 2026-02-11 | Revised: Cloud-Init/template strategy, LXC constraints, rollout, SSH cleanup |
