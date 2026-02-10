<!-- LAST EDITED: 2026-02-10 -->

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

### Two-Layer Approach: Bootstrap + Common Role

#### Bootstrap Playbook (Day 0 — one-time, per host)

Runs as `root` on a fresh host. Creates the two standard users and applies minimal SSH hardening.
Requires manual verification between phases (prevents lockout).

**Users on every host:**

- `akonopcz` — Interactive admin (SSH keys from Vault, sudo WITH password)
- `ansible` — Automation user (SSH key from Vault, passwordless sudo)
- `root` — Locked after bootstrap (`PermitRootLogin no`)

**Separation rationale:** Bootstrap is fundamentally different from ongoing management:

- Runs as root (ansible user doesn't exist yet — chicken-and-egg)
- Requires interactive verification (SSH test between Phase 1 and 2)
- Cannot be automated in CI (manual step by design)

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

#### ssh.yml

Deploys `/etc/ssh/sshd_config.d/hardening.conf` as a template (single file, single source of truth).
Supersedes the individual `lineinfile` directives from bootstrap Phase 2.

Directives from ADR-0011: `LoginGraceTime`, `MaxAuthTries`, `MaxSessions`, `ClientAliveInterval`,
`X11Forwarding no`, `AllowTcpForwarding no`, `AllowAgentForwarding no`, strong ciphers, etc.

#### security.yml

**CrowdSec:**

- Install CrowdSec + firewall bouncer
- Base collections: `crowdsecurity/linux`, `crowdsecurity/sshd` (always)
- Service-specific collections via variable (e.g., `crowdsecurity/nginx`, `crowdsecurity/postfix`)
- Docker hosts: `DOCKER-USER` chain in bouncer config via `common_crowdsec_docker_host` variable

**auditd:**

- Install `auditd` + `audispd-plugins`
- Deploy ADR-0011 rules: sudoers, sshd_config, authorized_keys, passwd/shadow, cron, systemd
- Logrotate configuration

**sysctl:**

- Deploy `/etc/sysctl.d/99-hardening.conf` from ADR-0011
- IP spoofing, ICMP redirects, SYN flood, source routing, martian logging

#### sudo.yml

- Logging: `logfile`, `log_input`, `log_output`, `iolog_dir`
- Security: `passwd_timeout=1`, `timestamp_timeout=5`, `passwd_tries=3`, `secure_path`
- Logrotate for `/var/log/sudo.log` and `/var/log/sudo-io`

#### monitoring.yml

- `node_exporter`: install, systemd unit, configurable collectors via variable
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

- **User management** — stays in bootstrap (one-time, runs as root)
- **Firewall rules** — too host-specific, comes with VLAN migration (ADR-0002)
- **Docker installation** — separate role
- **Service configuration** — separate roles (mailcow, vaultwarden, pterodactyl, etc.)
- **Vault secrets** — Common role needs no secrets, only configuration values

### SSH Hardening Overlap (Bootstrap vs. Common)

Bootstrap Phase 2 sets individual directives via `lineinfile` in `sshd_config`.
Common role deploys a complete template to `sshd_config.d/hardening.conf`.
Directives in `sshd_config.d/` take precedence — Common role wins automatically. No conflict.

## Consequences

### Positive

- Consistent baseline across all ~20+ hosts
- ADR-0011 implemented as code (not just documentation)
- Idempotent — safe to run repeatedly, detects and fixes drift
- Tag-based selective execution (`--tags ssh`, `--tags security`, etc.)
- New host provisioning: Bootstrap → Common → Service role (predictable flow)

### Negative

- Initial effort to build and test the role (~2-3 sessions)
- All hosts must be Debian/Ubuntu (Alpine migration required for prometheus)
- CrowdSec setup has learning curve (collections, bouncer configuration)

### Neutral

- Bootstrap remains a separate, manual process (by design — safety over automation)
- CI integration comes later (lint first, then dry-run, then auto-deploy)

## Alternatives Considered

| Alternative                     | Rejected Because                                               |
| ------------------------------- | -------------------------------------------------------------- |
| Multi-OS role (Debian + Alpine) | 90% Debian, Alpine maintenance cost not worth it for 1 host    |
| User management in Common role  | Chicken-and-egg: ansible user must exist before Common can run |
| All-in-one playbook (no role)   | Not reusable, not testable, doesn't scale to 20+ hosts         |
| Skip Common, only service roles | Duplicated security config in every service role               |

## References

- [ADR-0011: Server Hardening Baseline](ADR-0011-server-hardening-baseline.md) — security directives
  implemented by this role
- [ADR-0003: HashiCorp Vault](ADR-0003-hashicorp-vault-secrets.md) — bootstrap uses Vault for SSH keys
- [ADR-0013: Least-Privilege API Token](ADR-0013-least-privilege-api-token.md) — principle applied to user permissions

## Changelog

| Date       | Change        |
| ---------- | ------------- |
| 2026-02-10 | Initial draft |
