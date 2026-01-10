# GitHub Actions Self-Hosted Runner - Maintenance Guide

This guide covers common maintenance tasks for the GitHub Actions self-hosted runner running on LXC container
`github-runner-prod-cz-01` (VMID 6200).

## Runner Information

- **Container Name:** github-runner-prod-cz-01
- **VMID:** 6200
- **IP Address:** Check `ansible/inventory/host_vars/github-runner-prod-cz-01.yml`
- **Service Name:** `actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service`
- **Installation Path:** `/opt/actions-runner`
- **User:** `github-runner`

## Common Maintenance Tasks

### Checking Runner Status

```bash
# SSH into the container
ssh root@<RUNNER_IP>

# Check service status
systemctl status actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service

# View recent logs
journalctl -u actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service -n 50 --no-pager

# Follow logs in real-time
journalctl -u actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service -f
```

### Restarting the Runner

```bash
# SSH into the container
ssh root@<RUNNER_IP>

# Restart the service
cd /opt/actions-runner
./svc.sh restart

# Verify it's running
systemctl status actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service
```

### Stopping the Runner

```bash
ssh root@<RUNNER_IP>
cd /opt/actions-runner
./svc.sh stop
```

### Starting the Runner

```bash
ssh root@<RUNNER_IP>
cd /opt/actions-runner
./svc.sh start
```

## Token Management

### Renewing the Runner Token

Runner tokens expire and need to be renewed periodically. Here's how:

#### 1. Get Removal Token

Go to: <https://github.com/dranelixx/server-infrastructure/settings/actions/runners>

Click on your runner and get a removal token.

#### 2. Stop and Remove Current Runner

```bash
# SSH into the container
ssh root@<RUNNER_IP>

# Stop the service
cd /opt/actions-runner
./svc.sh stop

# Uninstall the service
./svc.sh uninstall

# Remove the runner registration
su - github-runner
cd /opt/actions-runner
./config.sh remove --token <REMOVAL_TOKEN>
exit
```

#### 3. Get New Registration Token

Go to: <https://github.com/dranelixx/server-infrastructure/settings/actions/runners/new>

Copy the new registration token.

#### 4. Re-register the Runner

```bash
# As root, switch to github-runner user
su - github-runner
cd /opt/actions-runner

# Configure with new token
./config.sh --url https://github.com/dranelixx/server-infrastructure \
  --token <NEW_TOKEN> \
  --name github-runner-prod-cz-01 \
  --labels self-hosted,Linux,X64,terraform,proxmox \
  --work _work \
  --unattended

exit
```

#### 5. Reinstall and Start Service

```bash
# As root
cd /opt/actions-runner
./svc.sh install github-runner
./svc.sh start

# Verify
systemctl status actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service
```

## Updating the Runner

### Check Current Version

```bash
ssh root@<RUNNER_IP>
su - github-runner
cd /opt/actions-runner
./bin/Runner.Listener --version
```

### Update to Latest Version

```bash
# SSH into the container
ssh root@<RUNNER_IP>

# Stop the service
cd /opt/actions-runner
./svc.sh stop

# Get the latest version from GitHub
curl -s https://api.github.com/repos/actions/runner/releases/latest | \
  jq -r '.tag_name' | sed 's/v//'

# Example: Update to version 2.331.0
VERSION="2.331.0"

# Switch to github-runner user
su - github-runner
cd /opt/actions-runner

# Backup current installation
mkdir -p ~/runner-backups
cp -r /opt/actions-runner ~/runner-backups/runner-$(date +%Y%m%d-%H%M%S)

# Download new version
curl -o actions-runner-linux-x64-${VERSION}.tar.gz -L \
  https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-x64-${VERSION}.tar.gz

# Verify hash (get hash from GitHub releases page)
echo "<SHA256_HASH>  actions-runner-linux-x64-${VERSION}.tar.gz" | sha256sum -c

# Extract (this will overwrite binaries but keep configuration)
tar xzf ./actions-runner-linux-x64-${VERSION}.tar.gz

exit

# Restart service
cd /opt/actions-runner
./svc.sh start

# Verify new version
su - github-runner -c 'cd /opt/actions-runner && ./bin/Runner.Listener --version'
```

## Troubleshooting

### Runner Not Starting

```bash
# Check service status
systemctl status actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service

# Check logs for errors
journalctl -u actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service -n 100

# Common issues:
# - Token expired: Re-register the runner
# - Permissions: Check /opt/actions-runner ownership (should be github-runner:github-runner)
# - Network: Test connectivity to GitHub
```

### Network Connectivity Issues

```bash
# Test GitHub API connectivity
curl -I https://api.github.com

# Test Proxmox API connectivity
nc -zv 10.0.1.10 8006

# Check DNS resolution
nslookup api.github.com

# Check routing
ip route
```

### Permission Issues

```bash
# Fix ownership of runner directory
chown -R github-runner:github-runner /opt/actions-runner

# Verify permissions
ls -la /opt/actions-runner
```

### Runner Shows as Offline in GitHub

1. Check if the service is running:

   ```bash
   systemctl status actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service
   ```

2. Check network connectivity to GitHub

3. Verify the token is still valid (tokens expire after 1 hour if not used)

4. Re-register the runner if needed

### High Resource Usage

```bash
# Check CPU and memory usage
top -u github-runner

# Check running jobs
su - github-runner
cd /opt/actions-runner/_work
ls -la

# View detailed resource usage
systemctl status actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service
```

## Monitoring

### Key Metrics to Monitor

1. **Service Status:** Should be `active (running)`
2. **CPU/Memory:** Check container resources in Proxmox
3. **Disk Space:** Monitor `/opt/actions-runner/_work`
4. **Network Connectivity:** GitHub and Proxmox API access
5. **Job Success Rate:** Check GitHub Actions logs

### Automated Monitoring Script

```bash
#!/bin/bash
# Save as /usr/local/bin/check-runner-health.sh

SERVICE="actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service"

# Check if service is running
if ! systemctl is-active --quiet "$SERVICE"; then
    echo "ERROR: Runner service is not running"
    exit 1
fi

# Check disk space
DISK_USAGE=$(df /opt/actions-runner | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "WARNING: Disk usage is at ${DISK_USAGE}%"
fi

# Check GitHub connectivity
if ! curl -s -o /dev/null -w "%{http_code}" https://api.github.com | grep -q "200"; then
    echo "WARNING: Cannot reach GitHub API"
fi

echo "Runner health check passed"
```

## Backup and Recovery

### Backup Runner Configuration

```bash
# Backup runner configuration and credentials
tar -czf runner-backup-$(date +%Y%m%d).tar.gz \
  /opt/actions-runner/.credentials \
  /opt/actions-runner/.runner \
  /opt/actions-runner/config.sh
```

**Note:** The `.credentials` file contains sensitive information. Store backups securely.

### Disaster Recovery

If the runner container is lost:

1. Recreate the container using Terraform
2. Run the Ansible playbook:

   ```bash
   cd /opt/server-infrastructure/ansible
   ansible-playbook -i inventory/ playbooks/github_runner_setup.yml --limit github-runner-prod-cz-01
   ```

3. Register the runner with a new token
4. Restore any custom configurations if needed

## Security Best Practices

1. **Keep the runner updated** - Run updates monthly
2. **Rotate tokens regularly** - Every 3-6 months minimum
3. **Monitor logs** - Check for suspicious activity
4. **Limit runner permissions** - Only give access to required repositories
5. **Use runner groups** - Organize runners by environment/purpose
6. **Review runner labels** - Ensure workflows target the correct runners

## Related Documentation

- [GitHub Actions Runner Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Ansible Playbook: github_runner_setup.yml](/opt/server-infrastructure/ansible/playbooks/github_runner_setup.yml)
- [Terraform Configuration: current-state/main.tf](/opt/server-infrastructure/terraform/environments/current-state/main.tf)

## Support

For issues or questions:

- Check GitHub Actions logs: <https://github.com/dranelixx/server-infrastructure/actions>
- Review runner logs: `journalctl -u actions.runner.dranelixx-server-infrastructure.github-runner-prod-cz-01.service`
- Test runner: Run the "Self-Hosted Runner Test" workflow in GitHub Actions
