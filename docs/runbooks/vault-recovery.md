<!-- LAST EDITED: 2026-02-07 -->

# Vault Recovery Runbook

Emergency procedures for HashiCorp Vault seal/unseal, backup, and recovery.

Vault is accessed via `$VAULT_ADDR` (set in your shell profile or exported per session).

## Health Check

```bash
# From any machine with network access
curl -s "$VAULT_ADDR/v1/sys/health" | jq .

# Expected response (healthy, unsealed):
# { "initialized": true, "sealed": false, "standby": false, ... }

# From vault server
vault status
```

| HTTP Code | Meaning                       |
| --------- | ----------------------------- |
| 200       | Initialized, unsealed, active |
| 429       | Unsealed, standby             |
| 472       | DR secondary, active          |
| 473       | Performance standby           |
| 501       | Not initialized               |
| 503       | Sealed                        |

## Emergency Seal

If Vault is compromised or you suspect unauthorized access, seal it immediately:

```bash
# From vault server
vault operator seal

# Or via API (requires root/sudo token)
curl -X PUT \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/sys/seal"
```

**Impact:** All CI/CD pipelines will fail until Vault is unsealed. This is intentional - security first.

## Unseal Procedure

Vault uses Shamir's Secret Sharing. You need a threshold number of unseal keys.

### Where Unseal Keys Are Stored

Keys are split across three independent storage locations (threshold: 3 of 5).
No single location holds enough keys to unseal. You need access to at least two sources.

### Steps

```bash
# Check current seal status
vault status

# Unseal (repeat for each required key share)
vault operator unseal <KEY_SHARE_1>
vault operator unseal <KEY_SHARE_2>
vault operator unseal <KEY_SHARE_3>
# ... until threshold is met

# Verify
vault status
# sealed = false
```

### After Unseal

1. Verify health: `vault status`
2. Check audit log for anomalies: `tail -100 /var/log/vault/audit.log | jq .`
3. Verify CI/CD works: trigger a test workflow
4. If emergency seal was used: investigate the incident before resuming normal operations

## Backup (File Storage Backend)

Vault uses file storage at `/opt/vault/data`. Backup is a compressed tar of this directory.

### Manual Backup

```bash
tar czf /var/backups/vault/vault-data-$(date +%Y%m%d-%H%M%S).tar.gz -C /opt/vault data
```

### Automated Backup

Daily cron job at 02:00, 7 days retention:

```bash
# In root's crontab
0 2 * * * tar czf /var/backups/vault/vault-data-$(date +\%Y\%m\%d).tar.gz -C /opt/vault data && find /var/backups/vault/ -name "vault-data-*.tar.gz" -mtime +7 -delete
```

Additionally, Proxmox vzdump captures the entire LXC container daily.

### Restore from Backup

**WARNING:** This replaces ALL Vault data. Only use in disaster recovery.

```bash
# Stop Vault
systemctl stop vault

# Restore data directory
tar xzf /var/backups/vault/vault-data-YYYYMMDD.tar.gz -C /opt/vault

# Start and unseal
systemctl start vault
vault operator unseal <KEY_SHARE_1>
vault operator unseal <KEY_SHARE_2>
vault operator unseal <KEY_SHARE_3>
```

### Restore After Full Loss

If the Vault server is completely destroyed:

1. Provision new Vault server (LXC or VM)
2. Install Vault, configure with same storage path
3. Restore data directory from backup
4. Start Vault and unseal with original unseal keys
5. Update `VAULT_ADDR` in GitHub Secrets if endpoint changed
6. Verify CI/CD connectivity

> **Note:** After migration to VM, this will switch to Raft storage with snapshot API or borgmatic.

## Audit Log

```bash
# View recent audit entries
tail -50 /var/log/vault/audit.log | jq .

# Search for failed auth attempts
jq 'select(.type == "response" and .response.data.error != null)' /var/log/vault/audit.log

# Search for specific path access
jq 'select(.request.path | startswith("secret/data/"))' /var/log/vault/audit.log
```

## Troubleshooting

### Vault Won't Start

```bash
# Check service status
systemctl status vault

# Check logs
journalctl -u vault -n 50 --no-pager

# Common issues:
# - Port already in use
# - TLS certificate expired
# - Storage backend unreachable
```

### CI/CD Pipeline Fails with Vault Errors

1. Check Vault health: `curl -s "$VAULT_ADDR/v1/sys/health"`
2. If sealed (503): unseal using procedure above
3. If unreachable: check network, reverse proxy, firewall
4. If auth fails: verify AppRole credentials in GitHub Secrets
5. Check if Secret ID has expired: AppRole Secret IDs have a TTL

### Token/Lease Expired

```bash
# Check token info
vault token lookup

# Renew token (if renewable)
vault token renew

# Create new token if needed
vault token create -policy=<policy-name>
```
