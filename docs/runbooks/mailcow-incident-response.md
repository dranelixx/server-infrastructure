<!-- LAST EDITED: 2026-02-08 -->

# Mailcow Incident Response Runbook

Emergency procedures for the Mailcow server (mailcow-prod-de-ndg-01).
This server runs Mailcow and Vaultwarden on a Netcup VPS.

## 1. Detection

### Automated Alerts

| Source    | What                             | Channel                            |
| --------- | -------------------------------- | ---------------------------------- |
| CrowdSec  | Brute force, suspicious access   | CrowdSec console                   |
| AIDE      | File integrity changes           | Cron mail / manual check           |
| auditd    | sudoers changes, SSH key changes | `/var/log/audit/audit.log`         |
| Borgmatic | Backup success/failure           | ntfy (Vaultwarden), ntfy (Mailcow) |
| Mailcow   | Service health                   | Mailcow UI alerts                  |

### Manual Checks

```bash
# CrowdSec decisions (active bans)
sudo cscli decisions list

# AIDE check (compare against baseline)
sudo aide --check

# Audit log - recent SSH key or sudoers changes
sudo ausearch -k sudoers_changes -ts recent
sudo ausearch -k ssh_keys -ts recent

# Docker container health
docker ps --format "table {{.Names}}\t{{.Status}}"

# Failed login attempts
sudo journalctl -u ssh --since "1 hour ago" | grep -i "failed"
```

## 2. Triage

### Severity Classification

| Severity     | Criteria                                                      | Response Time     |
| ------------ | ------------------------------------------------------------- | ----------------- |
| **Critical** | Active data exfiltration, root compromise, Vaultwarden breach | Immediate         |
| **High**     | Unauthorized access, AIDE alerts on binaries, new SSH keys    | < 1 hour          |
| **Medium**   | CrowdSec bans spike, failed auth spike, config changes        | < 4 hours         |
| **Low**      | Single failed login, non-critical file changes                | Next business day |

### Quick Assessment

```bash
# Who is currently logged in?
w

# Recent logins
last -20

# Unexpected processes
ps auxf | grep -v -E '(docker|postfix|dovecot|rspamd|redis|mysql|nginx|php|sogo|clamd|unbound)'

# Unexpected listening ports
ss -tlnp

# Recent file modifications in critical paths
find /etc -mtime -1 -type f 2>/dev/null
find /opt/mailcow-dockerized -mtime -1 -type f 2>/dev/null
find /opt/docker/vaultwarden -mtime -1 -type f 2>/dev/null
```

## 3. Containment

### Isolate the Threat

```bash
# Block a specific IP immediately
sudo cscli decisions add --ip <ATTACKER_IP> --duration 720h --reason "incident response"

# Block a subnet
sudo cscli decisions add --range <CIDR> --duration 720h --reason "incident response"

# Emergency: disable all external SSH (keep console access via Netcup SCP)
sudo iptables -I INPUT -p tcp --dport 22 -j DROP
# Undo: sudo iptables -D INPUT -p tcp --dport 22 -j DROP
```

### Stop Compromised Services

```bash
# Stop Vaultwarden (if compromised)
cd /opt/docker/vaultwarden && docker compose down

# Stop Mailcow (if compromised)
cd /opt/mailcow-dockerized && docker compose down

# Stop individual Mailcow container
docker stop <container_name>
```

### Preserve Evidence

```bash
# Snapshot current state before cleanup
sudo tar czf /root/incident-$(date +%Y%m%d_%H%M%S).tar.gz \
  /var/log/audit/ \
  /var/log/auth.log* \
  /var/log/syslog* \
  /var/log/crowdsec/ \
  /var/lib/aide/aide.db

# Export CrowdSec alerts
sudo cscli alerts list -o json > /root/crowdsec-alerts-$(date +%Y%m%d).json

# Docker logs
docker logs --since 24h $(docker ps -aq) > /root/docker-logs-$(date +%Y%m%d).txt 2>&1
```

## 4. Investigation

### Audit Log Analysis

```bash
# All events in the last 24h
sudo ausearch -ts today

# File access on critical paths
sudo ausearch -f /etc/passwd -ts recent
sudo ausearch -f /etc/shadow -ts recent

# Commands run via sudo
sudo ausearch -m EXECVE -ts recent | grep sudo

# SSH key modifications
sudo ausearch -k ssh_keys
```

### CrowdSec Analysis

```bash
# Alert history
sudo cscli alerts list --since 24h

# Check specific scenario
sudo cscli alerts list --scenario crowdsecurity/ssh-bf

# Metrics
sudo cscli metrics
```

### AIDE Analysis

```bash
# Full check against baseline
sudo aide --check

# Check specific path
sudo aide --check --limit /etc
sudo aide --check --limit /opt/docker
```

### Docker Investigation

```bash
# Check for unauthorized containers
docker ps -a

# Inspect container changes (filesystem diff)
docker diff <container_name>

# Container resource usage (crypto mining?)
docker stats --no-stream
```

## 5. Recovery

### Restore from Backup (Vaultwarden)

```bash
# List available backups
docker exec -it vaultwarden_backup borgmatic list

# Restore latest
docker exec -it vaultwarden_backup borgmatic restore --archive latest

# Restore specific archive
docker exec -it vaultwarden_backup borgmatic restore --archive <archive_name>
```

### Restore from Backup (Mailcow)

```bash
# Mailcow built-in backup
cd /opt/mailcow-dockerized
./helper-scripts/backup_and_restore.sh backup all

# Restore
./helper-scripts/backup_and_restore.sh restore
```

### Rebuild AIDE Baseline (after verified clean state)

```bash
sudo aideinit
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Rotate Credentials

After any compromise, rotate:

1. **SSH keys** - generate new keys, deploy to server
2. **Vaultwarden admin token** - update in `.env`, restart
3. **Database passwords** - update in `.env` files, restart services
4. **Borgmatic passphrases** - if backup credentials exposed
5. **CrowdSec API keys** - `sudo cscli machines delete` + re-register

## 6. Post-Incident

### Checklist

- [ ] Root cause identified and documented
- [ ] Attack vector closed
- [ ] Credentials rotated
- [ ] AIDE baseline rebuilt
- [ ] Backups verified (not compromised)
- [ ] CrowdSec scenarios updated if needed
- [ ] Monitoring gaps identified and addressed
- [ ] Timeline documented

### Communication

- Notify affected users if Vaultwarden data was accessed
- Update CrowdSec community with new attack patterns
- Document lessons learned in this repository
