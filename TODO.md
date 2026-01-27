# TODO

Tracked improvements and planned work for this infrastructure.

## Priority 1 - Security (Critical)

- [ ] **Mailcow Hardening** - Exposed mail server needs security review
  - fail2ban configuration
  - Rate limiting
  - SPF/DKIM/DMARC verification
  - Disable unused services
  - Review open ports

- [ ] **Flat Network Firewall Audit** - Review current-state network segmentation
  - Check Proxmox firewall rules between VMs/LXCs
  - Verify pfSense rules for internal traffic
  - Document lateral movement risks

## Priority 2 - Backups

- [ ] **Proxmox vzdump → Hetzner Storage Box**
  - Configure vzdump for all VMs/LXCs
  - SSH key setup for Storage Box
  - Retention policy
  - Scheduling

- [ ] **Backup Monitoring in Grafana**
  - Decision: Prometheus (recommended - already in stack) vs InfluxDB
  - borgmatic metrics exporter
  - Dashboard for backup status
  - Alerts for failed backups

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

## Ongoing

- [ ] **ADRs (Architecture Decision Records)**
  - Create `docs/adr/` structure
  - Document past decisions retroactively
  - See `docs/adr/README.md` for template

- [ ] **Disaster Recovery Testing**
  - Schedule quarterly DR test
  - Document restore procedures
  - Test borgmatic restore
  - Test Vault recovery

- [ ] **Renovate for Dependency Updates**
  - Setup Renovate bot
  - Configure for Terraform providers
  - Auto-PR for updates

## Future / Nice-to-have

- [ ] **Netcup Piko VPS Setup**
  - Uptime Kuma for external monitoring
  - Consider: External Vault backup verification endpoint
