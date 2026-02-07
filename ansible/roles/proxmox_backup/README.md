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

| Variable                          | Default                         | Description                   |
| --------------------------------- | ------------------------------- | ----------------------------- |
| `proxmox_backup_remote_user`      | `""`                            | **Required.** Remote SSH user |
| `proxmox_backup_remote_host`      | `""`                            | **Required.** Remote host     |
| `proxmox_backup_remote_port`      | `23`                            | SSH port (Hetzner uses 23)    |
| `proxmox_backup_remote_path`      | `configs`                       | Remote directory path         |
| `proxmox_backup_ssh_key_path`     | `/root/.ssh/backup-storage-box` | Local SSH key path            |
| `proxmox_backup_ssh_key_generate` | `false`                         | Generate SSH key if missing   |
| `proxmox_backup_retention_days`   | `7`                             | Days to keep backups          |
| `proxmox_backup_cron_hour`        | `3`                             | Cron hour (0-23)              |
| `proxmox_backup_cron_minute`      | `0`                             | Cron minute (0-59)            |
| `proxmox_backup_paths`            | See defaults                    | List of paths to backup       |
| `proxmox_backup_excludes`         | See defaults                    | Patterns to exclude           |
| `proxmox_backup_ntfy_enabled`     | `false`                         | Enable ntfy notifications     |
| `proxmox_backup_ntfy_url`         | `""`                            | ntfy topic URL                |
| `proxmox_backup_ntfy_token`       | `""`                            | ntfy auth token               |

## Example Playbook

```yaml
- hosts: proxmox
  roles:
    - role: proxmox_backup
      vars:
        proxmox_backup_remote_user: "u480474-sub1"
        proxmox_backup_remote_host: "u480474-sub1.your-storagebox.de"
        proxmox_backup_ssh_key_path: "/root/.ssh/backup-storage-box-01"
        proxmox_backup_retention_days: 7
        proxmox_backup_cron_hour: 3
```

## Tags

- `proxmox-backup` - All tasks
- `validate` - Validation only
- `ssh-key` - SSH key tasks
- `script` - Script deployment
- `cron` - Cron job
- `logrotate` - Logrotate config

## Manual SSH Key Setup

If not using `proxmox_backup_ssh_key_generate`, create the key manually:

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
