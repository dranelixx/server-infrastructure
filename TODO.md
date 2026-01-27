<!-- LAST EDITED: 2026-01-27 -->

# TODO

Tracked improvements and planned work for this infrastructure.

## Priority 1 - Security (Critical)

### 🔐 Fort Knox Tier (Highest Priority)

- [ ] **Vaultwarden Hardening** - Password manager for family & friends
  - CRITICAL: Other people's credentials at stake
  - Reverse proxy hardening (rate limiting, fail2ban)
  - Admin panel disabled or IP-restricted
  - 2FA enforcement for all users
  - Disable registrations (invite-only)
  - Regular security updates (Watchtower or manual)
  - Backup encryption verification
  - Consider: Dedicated VM instead of shared hosting

- [ ] **Mailcow Hardening** - Clean since Feb 2025 rebuild, hardening still needed
  - **Incident Response Readiness** (be prepared for next time)
    - Centralized logging (all auth attempts, sudo usage)
    - File Integrity Monitoring (AIDE or Tripwire)
    - Alert on sudoers file changes
    - Alert on new SSH keys added
    - Baseline documentation (what is "normal")
    - Incident response runbook
  - **Hardening**
    - fail2ban with aggressive bans
    - Rate limiting on SMTP/IMAP
    - SPF/DKIM/DMARC verification
    - Disable unused services (POP3?)
    - Review and minimize open ports
    - Regular Mailcow updates
  - **Forensics Learning** (if old snapshot still exists)
    - Analyze compromised snapshot in isolated VM
    - Find initial access vector
    - Document persistence mechanisms (sudoers, crontabs, authorized_keys)
    - Write incident report for personal learning

- [ ] **HashiCorp Vault Hardening** - Central secrets management
  - Same "Fort Knox" standard as Vaultwarden
  - Audit logging enabled and monitored
  - Seal/unseal procedures documented
  - Network isolation (not accessible from everywhere)
  - Regular token/lease rotation
  - Alert on failed auth attempts

### Standard Security Tasks

- [ ] **Flat Network Firewall Audit** - Review current-state network segmentation
  - Check Proxmox firewall rules between VMs/LXCs
  - Verify pfSense rules for internal traffic
  - Document lateral movement risks

- [ ] **GitHub Runner Hardening** - Mitigate private network access risks
  - After VLAN migration: isolate runner in restricted segment
  - Create dedicated API token with minimal permissions (not root)
  - Restrict workflows to protected branches with PR approval only
  - Evaluate migration to Docker-based ephemeral runner

- [ ] **LXC Security Review** - Audit workload placement
  - Migrate Vault from LXC to VM (secrets management needs max isolation)
  - Review privileged vs unprivileged LXC configurations
  - Migrate Pterodactyl Wings to VM for better isolation

- [ ] **TLS Hardening** - Fix insecure Proxmox API connection
  - Change Vault API endpoint from IP to domain (HAProxy + Let's Encrypt)
  - Set `proxmox_tls_insecure = false`

## Priority 2 - Backups

- [ ] **Proxmox vzdump → PBS**
  - Acquire budget tower server for PBS
  - Contact Coolhousing: Can tower join same internal network as rack?
  - Configure vzdump for all VMs/LXCs
  - Retention policy and scheduling

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

- [ ] **Vault Backup Strategy** (instead of HA - see ADR)
  - Automated Vault snapshots
  - Unseal keys in secure location (not on same infra)
  - Recovery runbook

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

- [ ] **Migrate Terraform Cloud → S3 Hybrid**
  - Primary: S3 in Frankfurt (native locks with `use_lockfile = true`)
  - DR/Dev: MinIO on TrueNAS
  - Reason: TF Cloud Free Tier ends 2026-03-31, RUM pricing too expensive

- [ ] **Module Versioning**
  - Introduce semantic versioning with Git tags
  - PATCH for bug fixes, MINOR for features, MAJOR for breaking changes
  - Pin environments to stable versions

## Ongoing

- [x] **ADRs (Architecture Decision Records)** ✓
  - Created `docs/adr/` structure with 10 ADRs
  - See `docs/adr/README.md` for index
  - See `docs/adr/ADR-QUESTIONS.md` for original Q&A

- [ ] **Disaster Recovery Testing**
  - Schedule quarterly DR test
  - Document restore procedures
  - Test borgmatic restore
  - Test Vault recovery

- [ ] **Renovate for Dependency Updates**
  - Setup Renovate bot
  - Configure for Terraform providers
  - Auto-PR for updates

- [ ] **Tech Debt Cleanup**
  - Revisit `lifecycle { ignore_changes }` in VM module
  - Remove workarounds where provider is now stable
  - Bring more attributes back under Terraform management

- [ ] **Evaluate terraform_docs in CI**
  - Currently disabled in pre-commit (modifies files after staging)
  - Consider running in CI instead of locally

## Future / Nice-to-have

- [ ] **Netcup Piko VPS Setup**
  - Uptime Kuma for external monitoring
  - Consider: External Vault backup verification endpoint

- [ ] **Publish Terraform Modules**
  - Make proxmox-vm and proxmox-lxc modules more generic
  - Publish to Terraform Registry for other Proxmox users

- [ ] **NetBox as Source of Truth**
  - Phase 1: Hosts, VMs, IPs, VLANs (automation-relevant)
  - Phase 2: Hardware details (PCIe, serial numbers, cables)
  - Terraform/Ansible reads from NetBox API
  - Potential: Proxmox SDN integration
