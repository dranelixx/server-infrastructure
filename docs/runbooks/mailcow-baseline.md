<!-- LAST EDITED: 2026-02-08 -->

# Mailcow Server Baseline

What "normal" looks like on mailcow-prod-de-ndg-01 (Netcup VPS).
Use this as reference during incident investigation to identify anomalies.

**Last verified:** 2026-02-08

## Docker Containers (22 total)

### Mailcow (19 containers)

| Container              | Purpose                    |
| ---------------------- | -------------------------- |
| nginx-mailcow          | Reverse proxy              |
| postfix-mailcow        | SMTP server                |
| dovecot-mailcow        | IMAP server                |
| rspamd-mailcow         | Spam filter                |
| mysql-mailcow          | Database                   |
| redis-mailcow          | Cache                      |
| sogo-mailcow           | Webmail                    |
| php-fpm-mailcow        | PHP processing             |
| clamd-mailcow          | Antivirus (ClamAV)         |
| unbound-mailcow        | DNS resolver               |
| acme-mailcow           | TLS certificate management |
| watchdog-mailcow       | Health monitoring          |
| ofelia-mailcow         | Cron scheduler             |
| postfix-tlspol-mailcow | TLS policy enforcement     |
| netfilter-mailcow      | Firewall rules             |
| dockerapi-mailcow      | Docker API proxy           |
| memcached-mailcow      | Cache                      |
| olefy-mailcow          | Document analysis          |
| borgmatic-mailcow      | Backup agent               |

### Vaultwarden (3 containers)

| Container          | Purpose                    |
| ------------------ | -------------------------- |
| vaultwarden_app    | Password manager (healthy) |
| vaultwarden_backup | Borgmatic backup agent     |
| vaultwarden_db     | MariaDB (healthy)          |

## Listening Ports

| Port | Protocol | Service                       |
| ---- | -------- | ----------------------------- |
| 22   | TCP      | SSH                           |
| 25   | TCP      | SMTP (Postfix)                |
| 80   | TCP      | HTTP (nginx, redirect to 443) |
| 143  | TCP      | IMAP (Dovecot)                |
| 443  | TCP      | HTTPS (nginx)                 |
| 465  | TCP      | SMTPS (Postfix)               |
| 587  | TCP      | Submission (Postfix)          |
| 993  | TCP      | IMAPS (Dovecot)               |
| 4190 | TCP      | ManageSieve (Dovecot)         |

All ports listen on both IPv4 and IPv6. No unexpected ports should be open.

**Red flags:** Any port not in this list, especially high ports (crypto miners, reverse shells).

## System Users with Shell Access

| User     | UID  | Shell        | Purpose |
| -------- | ---- | ------------ | ------- |
| root     | 0    | /usr/bin/zsh | System  |
| akonopcz | 1000 | /usr/bin/zsh | Admin   |

**Red flags:** Any new user with a shell, especially UID 0 duplicates.

## Running Services

| Service                   | Purpose                    |
| ------------------------- | -------------------------- |
| auditd                    | Security auditing          |
| containerd                | Container runtime          |
| cron                      | Scheduled tasks            |
| crowdsec                  | Intrusion detection        |
| crowdsec-firewall-bouncer | Ban enforcement (iptables) |
| docker                    | Container engine           |
| ssh                       | Remote access              |
| systemd-timesyncd         | NTP                        |
| unattended-upgrades       | Automatic security updates |
| qemu-guest-agent          | VM guest tools             |

**Red flags:** Unexpected services, disabled security services (crowdsec, auditd).

## Security Stack

| Component           | Status     | Config                                              |
| ------------------- | ---------- | --------------------------------------------------- |
| CrowdSec            | Active     | postfix, dovecot, nginx collections                 |
| CrowdSec Bouncer    | Active     | iptables mode, DOCKER-USER chain                    |
| auditd              | Active     | sudoers, SSH key, cron monitoring                   |
| AIDE                | Active     | Daily integrity check via cron (see excludes below) |
| unattended-upgrades | Active     | Automatic security patches                          |
| SPF/DKIM/DMARC      | Configured | p=reject                                            |

## Backup Schedule

| Service     | Tool      | Schedule  | Destination                    |
| ----------- | --------- | --------- | ------------------------------ |
| Mailcow     | Borgmatic | Automated | Hetzner Storage Box            |
| Vaultwarden | Borgmatic | Automated | Hetzner Storage Box + BorgBase |

## AIDE Excludes

Configured in `/etc/aide/aide.conf.d/99_aide_local_excludes`. Excluded paths:

- Docker/containerd runtime (`/var/lib/docker`, `/var/lib/containerd`, `/run/containerd`, `/run/docker/containerd`)
- CrowdSec runtime DB (`/var/lib/crowdsec/data`)
- Log files (`/var/log/{crowdsec*,audit,sudo-io,sudo.log,aide,vaultwarden}`)
- Borgmatic logs, systemd timer stamps, shell history, `/tmp`

Docker binaries (`/usr/bin/docker`, `/usr/bin/containerd`) are still monitored.

## How to Verify Baseline

```bash
# Compare running containers
docker ps --format "{{.Names}}" | sort

# Compare listening ports
ss -tlnp | grep -v 127.0.0

# Compare users with shell
grep -v nologin /etc/passwd | grep -v /false

# Compare running services
systemctl list-units --type=service --state=running --no-pager

# AIDE integrity check
sudo aide --check
```
