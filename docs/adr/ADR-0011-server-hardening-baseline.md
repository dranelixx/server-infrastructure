<!-- LAST EDITED: 2026-01-28 -->

# ADR-0011: Server Hardening Baseline

## Status

Accepted

## Context

Our infrastructure includes multiple Linux servers (Debian/Ubuntu) hosting various services.
After a security incident in early 2025, we needed a standardized hardening baseline
that can be applied consistently across all servers regardless of their specific workload.

Key requirements:

- Defense in depth approach
- Automated security updates
- Intrusion detection and logging
- Minimal attack surface
- Forensic readiness for incident response

## Decision

We adopt the following hardening baseline for all production servers. This serves as a **minimum
standard** - individual servers may have additional hardening based on their role.

### 1. Intrusion Detection: CrowdSec (not fail2ban)

**Choice:** CrowdSec over fail2ban

**Rationale:**

- Crowd-sourced threat intelligence (shared blocklists)
- Better Docker integration (DOCKER-USER chain support)
- Modern architecture with separate detection and remediation
- Active community with service-specific collections

**Base Collections** (install on every server):

```bash
cscli collections install crowdsecurity/linux
cscli collections install crowdsecurity/sshd
```

**Service-specific Collections** (install as needed):

- `crowdsecurity/nginx` - Web servers
- `crowdsecurity/postfix` / `crowdsecurity/dovecot` - Mail servers
- `crowdsecurity/mariadb` - Database servers
- etc.

**Firewall Bouncer Configuration** (`/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`):

```yaml
mode: iptables
iptables_chains:
  - INPUT
  - FORWARD
  - DOCKER-USER # Essential for protecting Docker containers
```

### 2. Automatic Security Updates: unattended-upgrades

**Configuration** (`/etc/apt/apt.conf.d/50unattended-upgrades`):

```text
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";  // Manual reboot decision
Unattended-Upgrade::SyslogEnable "true";
```

**Rationale:** Security updates should be automatic. Reboots remain manual for production
services to allow planned maintenance windows.

### 3. SSH Hardening

**Configuration** (`/etc/ssh/sshd_config.d/hardening.conf`):

```text
# Timeouts
LoginGraceTime 30
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 3

# Disable unnecessary features (attack surface reduction)
AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no
Compression no

# Logging
LogLevel VERBOSE

# Session limits
MaxSessions 2

# Strong ciphers only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,diffie-hellman-group18-sha512

# Legal banner
Banner /etc/issue.net
```

**Prerequisites** (verify these are set):

- `PermitRootLogin no`
- `PasswordAuthentication no`
- Key-based authentication only

### 4. Kernel/Network Hardening (sysctl)

**Configuration** (`/etc/sysctl.d/99-hardening.conf`):

```ini
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Don't send ICMP redirects (we're not a router)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Log Martian packets (spoofed, source-routed, redirect)
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
```

Apply with: `sudo sysctl --system`

### 5. Audit Logging (auditd)

**Installation:**

```bash
sudo apt install -y auditd audispd-plugins
```

**Configuration** (`/etc/audit/rules.d/hardening.rules`):

```text
# Persistence mechanism monitoring
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d/ -p wa -k sshd_config
-w /root/.ssh/authorized_keys -p wa -k authorized_keys
-w /home/ -p wa -k home_changes

# Identity file monitoring
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes

# Cron monitoring (common persistence mechanism)
-w /etc/crontab -p wa -k cron_changes
-w /etc/cron.d/ -p wa -k cron_changes
-w /var/spool/cron/ -p wa -k cron_changes

# Systemd service monitoring
-w /etc/systemd/system/ -p wa -k systemd_changes
-w /lib/systemd/system/ -p wa -k systemd_changes
```

**Rationale:** These rules monitor common persistence mechanisms used by attackers.
Essential for forensic analysis after incidents.

### 6. Sudo Hardening

**Configuration** (add via `visudo`):

```text
# Logging
Defaults    logfile="/var/log/sudo.log"
Defaults    log_input, log_output
Defaults    iolog_dir="/var/log/sudo-io"

# Security
Defaults    passwd_timeout=1
Defaults    timestamp_timeout=5
Defaults    passwd_tries=3
Defaults    secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
```

### 7. Log Rotation

Ensure logrotate is configured for all security-relevant logs to prevent disk exhaustion.

**Sudo Logs** (`/etc/logrotate.d/sudo`):

```text
/var/log/sudo.log {
    weekly
    rotate 12
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
}

/var/log/sudo-io/*/* {
    monthly
    rotate 6
    compress
    missingok
    notifempty
}
```

**Rationale:**

- Prevents disk exhaustion (potential DoS)
- Maintains log history for incident response (recommended: 30-90 days minimum)
- Compressed logs save space while preserving forensic evidence

### 8. User Security

- **Root password:** Locked (`passwd -l root`)
- **Emergency access:** Via hosting provider console (with 2FA if available)
- **SSH keys:** Ed25519 preferred, RSA 4096-bit minimum

### 9. Legal Banner

**File** (`/etc/issue.net` and `/etc/issue`):

```text
═══════════════════════════════════════════════════════════════════
                    AUTHORIZED ACCESS ONLY
═══════════════════════════════════════════════════════════════════

  This system is monitored 24/7. All connections are logged.

  - IP addresses recorded
  - Session activity captured
  - Intrusion detection ACTIVE
  - Law enforcement will be notified of unauthorized access

  Disconnect NOW if you are not authorized.

═══════════════════════════════════════════════════════════════════
```

**Rationale:** Legal requirement in some jurisdictions for prosecution of unauthorized access.

## Explicitly NOT Included

| Item                                    | Reason                                             |
| --------------------------------------- | -------------------------------------------------- |
| Separate partitions (/home, /tmp, /var) | Not feasible on most VPS                           |
| GRUB password                           | VPS provider has console access anyway             |
| USB/Firewire disable                    | No physical access to VPS                          |
| fail2ban                                | CrowdSec is superior replacement                   |
| AIDE (file integrity)                   | Considered, may add later for critical servers     |
| Non-standard SSH port                   | Security through obscurity, complicates management |

## Implementation Checklist

New server hardening checklist:

- [ ] Install CrowdSec + firewall bouncer
- [ ] Install base CrowdSec collections (linux, sshd)
- [ ] Install service-specific CrowdSec collections as needed
- [ ] Configure unattended-upgrades
- [ ] Apply SSH hardening config
- [ ] Apply sysctl hardening
- [ ] Install and configure auditd
- [ ] Configure sudo logging
- [ ] Configure log rotation for custom logs
- [ ] Lock root password
- [ ] Set legal banner
- [ ] Run Lynis audit (`lynis audit system --quick`)
- [ ] Reboot and verify all services

## Consequences

### Positive

- Consistent security baseline across all servers
- Automated security updates reduce maintenance burden
- Comprehensive logging enables incident response
- CrowdSec provides proactive threat blocking with crowd-sourced intelligence
- Reduced attack surface through disabled features

### Negative

- Slightly more complex initial setup (~30-60 minutes per server)
- Some SSH features disabled (forwarding) - use dedicated jump hosts if needed
- Audit logs consume disk space (mitigated by rotation)
- Manual reboots required after kernel updates

### Neutral

- Lynis score improved from ~50 to 66+ (target: 70+)
- Additional hardening possible but diminishing returns

## References

- [CrowdSec Documentation](https://docs.crowdsec.net/)
- [CrowdSec Hub - Collections](https://hub.crowdsec.net/)
- [Debian Security Manual](https://www.debian.org/doc/manuals/securing-debian-manual/)
- [Mozilla SSH Guidelines](https://infosec.mozilla.org/guidelines/openssh)
- [Lynis - Security Auditing Tool](https://cisofy.com/lynis/)

## Changelog

| Date       | Change          |
| ---------- | --------------- |
| 2026-01-28 | Initial version |
