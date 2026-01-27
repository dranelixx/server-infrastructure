<!-- LAST EDITED: 2026-01-27 -->

# ADR-0008: Backup Strategy

## Status

Accepted

## Context

Data protection requires multiple backup layers covering different scenarios:

- VM/container-level snapshots for quick recovery
- Application-level backups for granular restores
- Off-site storage for disaster recovery

## Decision

Implement a two-tier backup strategy:

### Tier 1: VM-Level Backups (vzdump + PBS)

| Component             | Purpose                              |
| --------------------- | ------------------------------------ |
| vzdump                | Proxmox native backup tool           |
| Proxmox Backup Server | Deduplication, verification, restore |
| Location              | Local PBS in same colocation         |

**TODO**: Acquire budget tower server for PBS, contact Coolhousing about internal network access.

### Tier 2: Application-Level Backups (Borgmatic)

| Component           | Purpose                                |
| ------------------- | -------------------------------------- |
| Borgmatic           | Wrapper around Borg for automation     |
| Borg                | Deduplication, encryption, compression |
| Hetzner Storage Box | Off-site storage                       |
| Vault integration   | Secrets for encryption keys            |

### Why both?

| Scenario               | vzdump/PBS         | Borgmatic      |
| ---------------------- | ------------------ | -------------- |
| VM won't boot          | ✅ Full restore    | ❌             |
| Restore single file    | ❌ Full VM restore | ✅ Granular    |
| Database point-in-time | ❌                 | ✅ With hooks  |
| Off-site DR            | ❌ Local only      | ✅ Storage Box |
| Speed                  | ✅ Fast local      | Slower remote  |

## Consequences

### Positive

- Multiple recovery options for different scenarios
- Deduplication reduces storage costs
- Encryption at rest (Borg)
- Off-site copy for disaster recovery

### Negative

- Two systems to maintain and monitor
- Restore procedures differ per tier
- PBS requires additional hardware

### Monitoring (TODO)

- Prometheus with borgmatic_exporter
- Grafana dashboard for backup status
- Alerts for failed backups
- Migrate from ntfy to Apprise for flexible notifications

## Alternatives Considered

| Alternative                 | Why Not Chosen                                |
| --------------------------- | --------------------------------------------- |
| vzdump only                 | No granular restore, no off-site              |
| Borgmatic only              | Can't restore full VMs quickly                |
| Veeam                       | Expensive licensing                           |
| Restic                      | Less mature than Borg, no Proxmox integration |
| Cloud backup (Backblaze B2) | Egress costs, slower than Storage Box         |
