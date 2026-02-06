<!-- LAST EDITED: 2026-02-05 -->

# ADR-0008: Backup Strategy

## Status

Accepted (Implemented 2026-02-05)

## Context

Data protection requires multiple backup layers covering different scenarios:

- VM/container-level snapshots for quick recovery
- Application-level backups for granular restores
- Off-site storage for disaster recovery

## Decision

Implement a two-tier backup strategy:

### Tier 1: VM-Level Backups (vzdump)

| Component             | Purpose                                 |
| --------------------- | --------------------------------------- |
| vzdump                | Proxmox native backup tool              |
| Proxmox Backup Server | Deduplication, verification, restore    |
| Location              | Off-site (Hetzner) + Local PBS (future) |

#### Current Implementation (Interim)

Until PBS hardware is acquired, vzdump backs up to Hetzner Storage Box via CIFS:

| Setting     | Value                             |
| ----------- | --------------------------------- |
| Storage     | `hetzner-vzdump` (CIFS)           |
| Target      | `u480474-sub1.your-storagebox.de` |
| Schedule    | Daily 01:00                       |
| Retention   | 7 days                            |
| Bandwidth   | 15 MB/s limit                     |
| Compression | zstd                              |

**Critical VMs (daily):** 1000, 1100, 3100, 4000, 5000, 6100

**Why CIFS over Borg for VMs:**

- Direct restore from Proxmox UI (no extraction step)
- No local temp space required
- Native vzdump integration
- Fast recovery in emergency

#### Proxmox Config Backups (rsync)

Separate from VM backups, Proxmox host configs are backed up via rsync:

| Setting      | Value                                   |
| ------------ | --------------------------------------- |
| Script       | `/usr/local/bin/backup-pve-configs.sh`  |
| Target       | Same Storage Box, `/configs/` directory |
| Schedule     | Daily 03:00                             |
| Retention    | 7 days                                  |
| Ansible Role | `proxmox-backup`                        |

**Paths backed up:** `/etc/pve`, `/etc/network`, `/etc/hosts`, `/etc/modprobe.d`, `/etc/systemd/system`, `/root`

#### Future: Local PBS

**TODO**: Acquire budget tower server for PBS, contact Coolhousing about internal network access.

Once PBS is available:

- Primary: Local PBS (fast restore)
- Secondary: Hetzner CIFS (off-site DR)

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
