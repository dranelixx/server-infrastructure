<!-- LAST EDITED: 2026-02-11 -->

# TODO

Tracked improvements and planned work for this infrastructure.

## Priority 1 - Security (Critical)

### 🔐 Fort Knox Tier (Highest Priority)

- [x] **Vaultwarden Hardening** - Password manager for family & friends ✓ (2026-01-28)
  - [x] Reverse proxy hardening (rate limiting, CrowdSec)
  - [x] Admin panel IP-restricted (localhost only, SSH tunnel required)
  - [x] Registrations disabled (SIGNUPS_ALLOWED=false)
  - [x] Security headers configured (X-Frame-Options, CSP, etc.)
  - [x] CrowdSec vaultwarden collection installed
  - [x] 2FA available (enforcement is user responsibility)
  - [x] Backup encryption verification (repokey BLAKE2b + repokey AES-256)

- [x] **Mailcow Hardening** - Clean since Feb 2025 rebuild ✓ (2026-01-28)
  - **Incident Response Readiness**
    - [x] Centralized logging (auditd + sudo logging)
    - [x] Alert on sudoers file changes (auditd)
    - [x] Alert on new SSH keys added (auditd)
    - [x] File Integrity Monitoring (AIDE) with daily cron check
    - [x] Baseline documentation (docs/runbooks/mailcow-baseline.md)
    - [x] Incident response runbook (docs/runbooks/mailcow-incident-response.md)
  - **Hardening**
    - [x] CrowdSec (replacing fail2ban) with postfix, dovecot, nginx collections
    - [x] SPF/DKIM/DMARC verified (p=reject)
    - [x] POP3 disabled (bound to localhost)
    - [x] Ports reviewed (unnecessary services disabled)

- [ ] **HashiCorp Vault Hardening** - Central secrets management
  - Same "Fort Knox" standard as Vaultwarden
  - [x] TLS verification enforced in CI/CD (removed tlsSkipVerify)
  - [x] Audit logging enabled (/var/log/vault/audit.log + logrotate)
  - [x] Seal/unseal procedures documented (docs/runbooks/vault-recovery.md)
  - [x] Prometheus alert rules (VaultSealed, VaultDown, VaultTooManyAuthFailures)
  - [ ] Network isolation (blocked by VLAN migration)
  - [x] Automated Secret ID rotation (weekly workflow + 14d TTL)
  - [x] User account created (no more root-only access)

### Standard Security Tasks

- [x] **Flat Network Firewall Audit** - Review current-state network segmentation ✓ (2026-02-07)
  - [x] Check Proxmox firewall rules between VMs/LXCs (disabled at all levels)
  - [x] Verify pfSense rules for internal traffic (LAN allow-all, no east-west filtering)
  - [x] Document lateral movement risks
  - [x] Removed unnecessary Plex NAT rules (5353, 1900, 32469, 3005, 8324, 32410-32414)

- [ ] **GitHub Runner Hardening** - Mitigate private network access risks
  - After VLAN migration: isolate runner in restricted segment
  - [x] Create dedicated API token with minimal permissions (ADR-0013, 2026-02-10)
  - [x] Remove sudo group membership, scoped sudoers (systemctl only)
  - [x] Systemd hardening (19 directives via drop-in override)
  - [x] Fix Terraform version pinning (1.7.5 → 1.14.3)
  - [x] Bootstrap: dedicated users (akonopcz + ansible), SSH key-only, root disabled
  - Restrict workflows to protected branches with PR approval only
  - Evaluate migration to Docker-based ephemeral runner

- [ ] **LXC Security Review** - Audit workload placement
  - Migrate Vault from LXC to VM (secrets management needs max isolation)
    - Switch file → Raft storage backend during migration
    - Set up Vault backup via Raft snapshots or borgmatic (see docs/guides/borgmatic-vault-integration.md)
  - Review privileged vs unprivileged LXC configurations
  - Migrate Pterodactyl Wings to VM for better isolation

- [x] **TLS Hardening** - Fix insecure Proxmox API connection ✓ (2026-02-07)
  - [x] HAProxy backend for Proxmox API (Let's Encrypt wildcard cert via pfSense)
  - [x] Vault API endpoint changed from IP to domain
  - [x] Set `proxmox_tls_insecure = false` (variables + CI/CD workflows)

## Priority 2 - Backups

- [x] **Proxmox vzdump → Hetzner Storage Box** ✓ (2026-02-05)
  - [x] CIFS storage configured (hetzner-vzdump)
  - [x] vzdump job for critical VMs (1000, 1100, 3100, 4000, 5000, 6100)
  - [x] rsync config backup script (Ansible role: proxmox-backup)
  - [x] Daily schedule (vzdump 01:00, rsync 03:00)
  - [x] Restore test (verify VM boots after restore) ✓ (2026-02-06)

- [ ] **Proxmox vzdump → PBS** (future)
  - Acquire budget tower server for PBS
  - Contact Coolhousing: Can tower join same internal network as rack?
  - On-site backup complement to off-site Hetzner

- [ ] **Backup Notifications from Vault**
  - [ ] Fetch ntfy token from Vault in proxmox-backup role
  - [ ] Evaluate: direct Vault CLI vs. Ansible lookup
  - Blocked by: Apprise migration (below)

- [ ] **Backup Monitoring in Grafana**
  - Use Prometheus (already in stack) with borgmatic_exporter
  - Dashboard for backup status
  - Alerts for failed backups

- [ ] **Migrate ntfy → Apprise**
  - Apprise supports 80+ notification services
  - Configure multiple outputs (Telegram, Discord, Email)
  - Fallback notifications if one service fails

## Priority 3 - Secrets Management

- [ ] **Complete Vault Migration**
  - Audit remaining hardcoded secrets
  - Migrate Ansible secrets to Vault
  - Document Vault paths
  - Migrate `secret/shared/ssh` → `secret/shared/akonopcz` (public_keys), then delete old path

- [ ] **Vault Backup Strategy** (instead of HA - see ADR)
  - [x] Automated Vault data backup (daily tar cron, borgmatic after VM migration)
  - [x] Unseal keys in secure location (split across 3 independent sources)
  - [x] Recovery runbook (docs/runbooks/vault-recovery.md)

## Priority 4 - IaC Continuation

- [ ] **Complete current-state mapping**
  - All VMs in Terraform
  - All LXCs in Terraform
  - Network configuration

- [ ] **Prepare target-state**
  - Copy from current-state
  - Adjust for VLANs 10/20/30
  - LACP bond configuration
  - Test with `terraform plan`

- [x] **Migrate Terraform Cloud → S3 Hybrid** ✓ (2026-02-09)
  - [x] Primary: S3 in Frankfurt (native locks with `use_lockfile = true`)
  - [ ] DR/Dev: MinIO on TrueNAS (future)
  - Reason: TF Cloud Free Tier ends 2026-03-31, RUM pricing too expensive

- [x] **Module Versioning** ✓ (2026-02-07)
  - [x] Semantic versioning with annotated Git tags (`modules/<name>/v<semver>`)
  - [x] Versioning strategy documented in ADR-0009
  - [x] Baseline tags: `proxmox-vm/v1.0.0`, `proxmox-lxc/v1.0.0`
  - Relative paths kept (no `git::` pinning - pragmatic for single-user)

- [x] **Map Hetzner infrastructure in Terraform** ✓ (2026-02-11)
  - [x] Hetzner Cloud VPS (cx23, fsn1) + Firewall imported
  - [x] Hetzner Storage Box (bx21, fsn1) imported
  - [x] Provider: [hetznercloud/hcloud v1.60.0](https://registry.terraform.io/providers/hetznercloud/hcloud/latest)
  - [x] delete_protection + prevent_destroy on all resources
  - [ ] CI/CD integration (terraform-plan.yml job for Hetzner)

- [ ] **Map Netcup infrastructure in Terraform**
  - Netcup VPS (Mailcow, Vaultwarden)
  - SCP provider: [rincedd/netcup-scp](https://github.com/rincedd/terraform-provider-netcup-scp)
  - CCP provider: [rincedd/netcup-ccp](https://github.com/rincedd/terraform-provider-netcup-ccp)
  - Bonus: Netcup SCP MCP endpoint for direct management

## Ongoing

- [x] **ADRs (Architecture Decision Records)** ✓
  - Created `docs/adr/` structure with 14 ADRs
  - See `docs/adr/README.md` for index
  - See `docs/adr/ADR-QUESTIONS.md` for original Q&A

- [ ] **Ansible Common Role** (ADR-0014)
  - [x] Review ADR-0014 with Ansible expert
  - [ ] Create Cloud-Init image for Proxmox VMs (users, qemu-guest-agent)
  - [ ] Create custom LXC template (users, ssh-users group, sudo)
  - [ ] Build Common role: packages, SSH, security, sudo, monitoring, time, banner
  - [ ] Deploy Common role to all hosts (canary first, then fleet)
  - [ ] Ansible CI: Phase 1 lint, Phase 2 dry-run, Phase 3 auto-deploy
  - [ ] Ansible drift detection workflow (scheduled `--check --diff`)

- [ ] **Disaster Recovery Testing**
  - Schedule quarterly DR test
  - Document restore procedures
  - Test borgmatic restore
  - Test Vault recovery

- [x] **Renovate for Dependency Updates** (2026-02-10)
  - [x] Setup Renovate bot (GitHub App)
  - [x] Configure for Terraform providers, GitHub Actions, pre-commit hooks
  - [x] Auto-PR for updates (schedule: Mondays before 9am)

- [x] **Migrate deprecated proxmox-vm variables → v2.0.0** ✓ (2026-02-09)
  - [x] Migrate VMs from `disk_size`/`storage_pool`/`emulate_ssd` to `disks` array
  - [x] Migrate same VMs in target-state (incl. `truenas`, `plex`)
  - [x] Remove `disk` from `lifecycle { ignore_changes }` (provider now stable)
  - [x] Remove deprecated variables from module → tag `modules/proxmox-vm/v2.0.0`

- [ ] **Migrate prometheus-prod-cz-01 from Alpine to Debian**
  - Only Alpine host in fleet, blocks unified Ansible Common role
  - Recreate LXC with Debian-Minimal, reinstall Prometheus + node_exporter
  - Minimal RAM difference (~50MB), not worth multi-OS role maintenance

- [ ] **Tech Debt Cleanup**
  - [x] Revisit `lifecycle { ignore_changes }` in VM module (disk removed, provider stable)
  - Remove workarounds where provider is now stable
  - Bring more attributes back under Terraform management

- [ ] **Varken Fork Updates** (dranelixx/varken:influxdb2)
  - Update `structures.py` for new Sonarr/Radarr API fields (`runtime`, `customFormatScore`, `lastSearchTime`, `releaseDate`)
  - Fix `dbmanager.py` token handling (use `password` directly as token, not `username:password`)
  - Update Python 3.9 → 3.11+
  - Consider: Fork cleanup or contribute upstream to Boerderij/Varken

- [ ] **Monitoring Stack Improvements**
  - node_exporter: Add collectors (`--collector.systemd`, `--collector.processes`, `--collector.tcpstat`)
  - node_exporter: Add `--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|run)($|/)`
  - node_exporter: Add `--collector.ipmi` for hardware health (temps, fans, disks)
  - snmp_exporter for pfSense/switches
  - Consider: cadvisor for container metrics
  - Mailcow update check (cronjob + ntfy notification)

- [ ] **Service Logs Refactoring**
  - Move logs from `/srv/*/config/logs/` to `/var/log/services/{service}/`
  - Standard Linux log structure, easier debugging
  - Only secret files (.env, config.yml, servers.yml) remain restricted in /srv/\*/config/

- [ ] **Centralized Log Aggregation**
  - Graylog container (9000) on pve-prod-cz-loki exists
  - Evaluate: keep centralized vs. decentralized with VPN to colo
  - Ship logs from all hosts to Graylog (rsyslog/filebeat/promtail)

- [x] **SSH Key Hardening** ✓ (2026-02-08)
  - [x] Passphrase on active key (id_ed25519)
  - [x] ssh-agent with timeout (AddKeysToAgent in SSH config)
  - [ ] Decommission old keys (id_ed25519_old, id_rsa) after migration on all servers
  - [ ] Ansible SSH key via direnv + Vault (no key on disk, consistent with Terraform `.envrc` pattern)
    - `ansible/.envrc`: `vault kv get -field=ssh_private_key secret/shared/ansible | ssh-add -`
    - Remove `ansible_ssh_private_key_file` from inventory (ssh-agent handles it)
    - Delete `~/.ssh/ansible_ed25519` from disk

- [ ] **Update Storage Upgrade Docs (P3500 Change)**
  - Only 1x Intel P3500 available instead of 2x
  - Update `docs/private/plans/storage-upgrade/` (README, 02-hardware, 03-pool-setup)
  - Decide: TrueNAS cache vs. Proxmox nvme-fast vs. split single drive
  - Wait until hardware actually ships before updating

- [ ] **Evaluate terraform_docs in CI**
  - Currently disabled in pre-commit (modifies files after staging)
  - Consider running in CI instead of locally

- [ ] **Add tfsec/Checkov Security Scanning**
  - tfsec for Terraform security checks
  - Checkov for policy-as-code validation
  - Integrate as pre-commit hook or CI step

## Future / Nice-to-have

- [ ] **Architecture Documentation (public version)**
  - Create `docs/architecture/` with current-state and target-state overviews
  - Network diagrams, VM/LXC placement, storage topology
  - Keep sensitive details (IPs, hostnames) out of public docs

- [ ] **Netcup Piko VPS Setup**
  - Uptime Kuma for external monitoring
  - Consider: External Vault backup verification endpoint

- [ ] **Vaultwarden Isolation** - Migrate to dedicated host for max isolation
  - Currently shares host with Mailcow (resource efficiency)
  - Proxmox at 88% RAM - no room for additional VM
  - Option: Hetzner CX23 (2 vCPU, 4GB, €3,56/mo) - Vaultwarden needs ~200MB
  - Evaluate if breach risk justifies cost

- [ ] **Publish Terraform Modules**
  - Make proxmox-vm and proxmox-lxc modules more generic
  - Publish to Terraform Registry for other Proxmox users

- [ ] **NetBox as Source of Truth**
  - Phase 1: Hosts, VMs, IPs, VLANs (automation-relevant)
  - Phase 2: Hardware details (PCIe, serial numbers, cables)
  - Terraform/Ansible reads from NetBox API
  - Potential: Proxmox SDN integration
