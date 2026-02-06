# Proxmox Backup Role

Deploys a configuration backup script for Proxmox VE hosts.
Backs up critical config files to remote storage (e.g., Hetzner Storage Box) via rsync over SSH.

## What gets backed up

- `/etc/pve` - Proxmox cluster config, VM configs, storage.cfg
- `/etc/network` - Network interfaces
- `/etc/hosts` - Host file
- `/etc/modprobe.d` - Kernel modules (GPU passthrough, etc.)
- `/etc/systemd/system` - Custom systemd units
- `/root` - Scripts, cron, etc.

## Requirements

- SSH key authentication to remote storage
- rsync installed on Proxmox host
- Remote storage with SSH access (tested with Hetzner Storage Box)

## Role Variables

| Variable                      | Default                         | Description                   |
| ----------------------------- | ------------------------------- | ----------------------------- |
| `pve_backup_remote_user`      | `""`                            | **Required.** Remote SSH user |
| `pve_backup_remote_host`      | `""`                            | **Required.** Remote host     |
| `pve_backup_remote_port`      | `23`                            | SSH port (Hetzner uses 23)    |
| `pve_backup_remote_path`      | `configs`                       | Remote directory path         |
| `pve_backup_ssh_key_path`     | `/root/.ssh/backup-storage-box` | Local SSH key path            |
| `pve_backup_ssh_key_generate` | `false`                         | Generate SSH key if missing   |
| `pve_backup_retention_days`   | `7`                             | Days to keep backups          |
| `pve_backup_cron_hour`        | `3`                             | Cron hour (0-23)              |
| `pve_backup_cron_minute`      | `0`                             | Cron minute (0-59)            |
| `pve_backup_paths`            | See defaults                    | List of paths to backup       |
| `pve_backup_excludes`         | See defaults                    | Patterns to exclude           |
| `pve_backup_ntfy_enabled`     | `false`                         | Enable ntfy notifications     |
| `pve_backup_ntfy_url`         | `""`                            | ntfy topic URL                |
| `pve_backup_ntfy_token`       | `""`                            | ntfy auth token               |

## Example Playbook

```yaml
- hosts: proxmox
  roles:
    - role: proxmox-backup
      vars:
        pve_backup_remote_user: "u480474-sub1"
        pve_backup_remote_host: "u480474-sub1.your-storagebox.de"
        pve_backup_ssh_key_path: "/root/.ssh/backup-storage-box-01"
        pve_backup_retention_days: 7
        pve_backup_cron_hour: 3
```

## Tags

- `proxmox-backup` - All tasks
- `validate` - Validation only
- `ssh-key` - SSH key tasks
- `script` - Script deployment
- `cron` - Cron job
- `logrotate` - Logrotate config

## Manual SSH Key Setup

If not using `pve_backup_ssh_key_generate`, create the key manually:

```bash
ssh-keygen -t ed25519 -C "root@$(hostname)" -f /root/.ssh/backup-storage-box-01 -N ""
cat /root/.ssh/backup-storage-box-01.pub | ssh -p 23 USER@HOST install-ssh-key
```

## Testing

After deployment, test manually:

```bash
/usr/local/bin/backup-pve-configs.sh
```

Check logs:

```bash
tail -f /var/log/pve-backup.log
```
