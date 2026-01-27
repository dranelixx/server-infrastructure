# Borgmatic Backup with HashiCorp Vault Integration

This guide describes how to integrate borgmatic backups with HashiCorp Vault for
centralized secrets management. Covers both local installations and Docker-based setups.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Vault Setup](#vault-setup)
  - [Secrets Structure](#secrets-structure)
  - [Policy](#policy)
  - [AppRole](#approle)
- [Server Setup - Local Installation](#server-setup---local-installation)
- [Server Setup - Docker Installation](#server-setup---docker-installation)
- [borgmatic Configuration](#borgmatic-configuration)
- [Systemd Timer](#systemd-timer)
- [Borg Passphrase Rotation](#borg-passphrase-rotation)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Vault Server

- HashiCorp Vault with KV v2 secrets engine enabled
- AppRole auth method enabled (`vault auth enable approle`)

### On Backup Server

- `vault` CLI installed
- `jq` installed
- borgmatic installed (local or Docker)
- SSH access to Borg repository (Hetzner Storage Box, BorgBase, etc.)

---

## Architecture Overview

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Backup Server  │────▶│  HashiCorp      │     │  Borg Repo      │
│                 │     │  Vault          │     │  (Storage Box)  │
│  - borgmatic    │     │                 │     │                 │
│  - wrapper.sh   │     │  - Secrets      │     │  - Archives     │
│  - systemd      │     │  - AppRole      │     │  - Encrypted    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │
        │   1. Authenticate     │
        │   2. Fetch secrets    │
        │   3. Run backup       │
        └───────────────────────┘
```

**Flow:**

1. Systemd timer triggers backup script
2. Script authenticates to Vault via AppRole
3. Script fetches secrets (borg passphrase, DB credentials, ntfy token)
4. Script runs borgmatic with secrets as environment variables
5. borgmatic creates encrypted backup to remote repository

---

## Vault Setup

### Secrets Structure

Organize secrets per service with consistent paths:

```text
secret/
└── prod/
    └── services/
        └── <service-name>/
            ├── backup/
            │   ├── borg_passphrase
            │   ├── server (optional: storage box hostname)
            │   └── username (optional: storage box user)
            ├── database/
            │   ├── db_name
            │   ├── db_user
            │   └── db_password
            └── monitoring/
                └── ntfy_token
```

**Create secrets:**

```bash
# Generate new borg passphrase
openssl rand -base64 48

# Store backup secrets
vault kv put secret/prod/services/<service-name>/backup \
  borg_passphrase="<GENERATED_PASSPHRASE>" \
  server="<STORAGE_BOX_HOST>" \
  username="<STORAGE_BOX_USER>"

# Store database secrets
vault kv put secret/prod/services/<service-name>/database \
  db_name="<DATABASE_NAME>" \
  db_user="<DATABASE_USER>" \
  db_password="<DATABASE_PASSWORD>"

# Store monitoring secrets
vault kv put secret/prod/services/<service-name>/monitoring \
  ntfy_token="<NTFY_ACCESS_TOKEN>"
```

### Policy

Create a read-only policy for the borgmatic service:

```bash
vault policy write borgmatic-<service-name> - <<EOF
path "secret/data/prod/services/<service-name>/backup" {
  capabilities = ["read"]
}
path "secret/data/prod/services/<service-name>/database" {
  capabilities = ["read"]
}
path "secret/data/prod/services/<service-name>/monitoring" {
  capabilities = ["read"]
}
EOF
```

### AppRole

Create an AppRole for automated authentication:

```bash
# Create the role
vault write auth/approle/role/borgmatic-<service-name> \
  token_policies="borgmatic-<service-name>" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0

# Get role ID (static, can be shared)
vault read auth/approle/role/borgmatic-<service-name>/role-id

# Generate secret ID (sensitive, store securely)
vault write -f auth/approle/role/borgmatic-<service-name>/secret-id
```

### Optional: IP Binding (for internal servers only)

```bash
vault write auth/approle/role/borgmatic-<service-name> \
  token_policies="borgmatic-<service-name>" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0 \
  secret_id_bound_cidrs="<SERVER_IP>/32" \
  token_bound_cidrs="<SERVER_IP>/32"
```

> **Note:** IP binding only works for servers with direct access to Vault.
> If traffic goes through NAT/reverse proxy, Vault sees the gateway IP instead.

---

## Server Setup - Local Installation

For services running directly on the host (not in Docker).

### 1. Install Vault CLI

```bash
# Debian/Ubuntu
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

### 2. Create AppRole Credentials File

```bash
sudo tee /etc/borgmatic/vault-approle.env > /dev/null << 'EOF'
VAULT_ADDR=https://<VAULT_HOSTNAME>:<PORT>
VAULT_ROLE_ID=<YOUR_ROLE_ID>
VAULT_SECRET_ID=<YOUR_SECRET_ID>
EOF

sudo chmod 600 /etc/borgmatic/vault-approle.env
```

### 3. Create Wrapper Script

```bash
sudo tee /usr/local/bin/borgmatic-backup.sh > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

# Load AppRole credentials and auto-export them
set -a
source /etc/borgmatic/vault-approle.env
set +a

# Get token via AppRole
VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$VAULT_ROLE_ID" \
  secret_id="$VAULT_SECRET_ID")

export VAULT_TOKEN

# Fetch secrets from Vault
BACKUP=$(vault kv get -format=json secret/prod/services/<service-name>/backup)
DATABASE=$(vault kv get -format=json secret/prod/services/<service-name>/database)
MONITORING=$(vault kv get -format=json secret/prod/services/<service-name>/monitoring)

# Export environment variables for borgmatic
export BORG_PASSPHRASE=$(echo "$BACKUP" | jq -r '.data.data.borg_passphrase')
export DB_NAME=$(echo "$DATABASE" | jq -r '.data.data.db_name')
export DB_USER=$(echo "$DATABASE" | jq -r '.data.data.db_user')
export DB_PASSWORD=$(echo "$DATABASE" | jq -r '.data.data.db_password')
export NTFY_ACCESS_TOKEN=$(echo "$MONITORING" | jq -r '.data.data.ntfy_token')

# Run borgmatic
/usr/local/bin/borgmatic --verbosity 1 "$@"
EOF

sudo chmod +x /usr/local/bin/borgmatic-backup.sh
```

---

## Server Setup - Docker Installation

For services running in Docker containers with borgmatic as a sidecar container.

### 1. Install Vault CLI

Same as local installation.

### 2. Create AppRole Credentials File

Store in the borgmatic config directory (varies by setup):

```bash
sudo tee /path/to/borgmatic/config/vault-approle.env > /dev/null << 'EOF'
VAULT_ADDR=https://<VAULT_HOSTNAME>:<PORT>
VAULT_ROLE_ID=<YOUR_ROLE_ID>
VAULT_SECRET_ID=<YOUR_SECRET_ID>
EOF

sudo chmod 600 /path/to/borgmatic/config/vault-approle.env
```

### 3. Create Wrapper Script

```bash
sudo tee /usr/local/bin/borgmatic-<service>-backup.sh > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

# Load AppRole credentials and auto-export them
set -a
source /path/to/borgmatic/config/vault-approle.env
set +a

# Get token via AppRole
VAULT_TOKEN=$(vault write -field=token auth/approle/login \
  role_id="$VAULT_ROLE_ID" \
  secret_id="$VAULT_SECRET_ID")

export VAULT_TOKEN

# Fetch secrets from Vault
BACKUP=$(vault kv get -format=json secret/prod/services/<service-name>/backup)
DATABASE=$(vault kv get -format=json secret/prod/services/<service-name>/database)
MONITORING=$(vault kv get -format=json secret/prod/services/<service-name>/monitoring)

# Export environment variables for borgmatic
export BORG_PASSPHRASE=$(echo "$BACKUP" | jq -r '.data.data.borg_passphrase')
export DBNAME=$(echo "$DATABASE" | jq -r '.data.data.db_name')
export DBUSER=$(echo "$DATABASE" | jq -r '.data.data.db_user')
export DBPASS=$(echo "$DATABASE" | jq -r '.data.data.db_password')
export NTFY_ACCESS_TOKEN=$(echo "$MONITORING" | jq -r '.data.data.ntfy_token')

# Run borgmatic via docker-compose
cd /path/to/docker-compose/directory
docker compose exec -T \
  -e BORG_PASSPHRASE \
  -e DBNAME \
  -e DBUSER \
  -e DBPASS \
  -e NTFY_ACCESS_TOKEN \
  <borgmatic-container-name> borgmatic --verbosity 1 "$@"
EOF

sudo chmod +x /usr/local/bin/borgmatic-<service>-backup.sh
```

> **Important:** The `-e VAR` syntax passes the variable from the host environment
> into the container. The variable must be exported in the script before this call.

---

## borgmatic Configuration

Update your borgmatic config to use environment variables:

```yaml
# Repository
repositories:
  - path: ssh://<user>@<host>:<port>/./
    label: primary-storage

# Compression
compression: auto,zstd
archive_name_format: "<service>-{now:%Y-%m-%d_%H:%M:%S}"

# Retention
keep_hourly: 24
keep_daily: 7
keep_weekly: 4
keep_monthly: 6
keep_yearly: 2

# Database (if applicable)
mariadb_databases:
  - name: ${DBNAME}
    hostname: <db-host>
    username: ${DBUSER}
    password: ${DBPASS}
    options: "--default-character-set=utf8mb4"

# Health checks
checks:
  - name: repository
    frequency: 1 week
  - name: archives
    frequency: 2 weeks

# Notifications
ntfy:
  topic: <service>-backups
  server: https://<ntfy-server>
  access_token: ${NTFY_ACCESS_TOKEN}
  start:
    title: Borgmatic Backup Started
    message: Backup in progress...
    tags: borgmatic
    priority: min
  finish:
    title: Borgmatic Backup Completed
    message: Backup successful!
    tags: borgmatic
    priority: min
  fail:
    title: Borgmatic Backup Failed
    message: Check logs immediately!
    tags: borgmatic,warning
    priority: max
  states:
    - start
    - finish
    - fail
```

---

## Systemd Timer

### Service Unit

```bash
sudo tee /etc/systemd/system/borgmatic-<service>.service > /dev/null << 'EOF'
[Unit]
Description=Borgmatic <service> backup
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/borgmatic-<service>-backup.sh
Nice=19
IOSchedulingClass=best-effort
IOSchedulingPriority=7
EOF
```

### Timer Unit

```bash
sudo tee /etc/systemd/system/borgmatic-<service>.timer > /dev/null << 'EOF'
[Unit]
Description=Run <service> borgmatic backup hourly

[Timer]
OnCalendar=*-*-* *:14:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

### Enable and Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable borgmatic-<service>.timer
sudo systemctl start borgmatic-<service>.timer

# Verify
systemctl list-timers | grep borgmatic
```

---

## Borg Passphrase Rotation

When rotating the borg passphrase, you must update both Vault AND the repository.

### 1. Create Backup First

```bash
# Local
borgmatic create --verbosity 1

# Docker
docker compose exec <borgmatic-container> borgmatic create --verbosity 1
```

### 2. Generate New Passphrase

```bash
openssl rand -base64 48
```

### 3. Store in Vault

```bash
vault kv patch secret/prod/services/<service-name>/backup \
  borg_passphrase="<NEW_PASSPHRASE>"
```

### 4. Change Passphrase in Repository

```bash
# Unset old passphrase from environment
unset BORG_PASSPHRASE

# Change passphrase (will prompt for old, then new twice)
borg key change-passphrase ssh://<user>@<host>:<port>/./
```

### 5. Export and Save New Key

```bash
borg key export --paper ssh://<user>@<host>:<port>/./
```

Save the paper key in your password manager (Bitwarden, 1Password, etc.).

### 6. Verify

```bash
export BORG_PASSPHRASE="<NEW_PASSPHRASE>"
borg list ssh://<user>@<host>:<port>/./
```

---

## Troubleshooting

### "VAULT_ADDR and -address unset"

The `VAULT_ADDR` environment variable is not being exported. Ensure `set -a` is before `source`:

```bash
set -a
source /path/to/vault-approle.env
set +a
```

### "invalid role or secret ID"

- Check for typos in role_id or secret_id
- Verify the AppRole exists: `vault read auth/approle/role/borgmatic-<service>`
- Generate new secret_id if needed: `vault write -f auth/approle/role/borgmatic-<service>/secret-id`

### "source address unauthorized by CIDR restrictions"

IP binding is configured but the request comes from a different IP. This happens when:

- Traffic goes through NAT/reverse proxy
- Server has multiple network interfaces

**Solution:** Remove IP binding or use the correct source IP:

```bash
vault write auth/approle/role/borgmatic-<service> \
  token_policies="borgmatic-<service>" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0
  # No CIDR restrictions
```

### "Cannot find variable in environment" (Docker)

Environment variables aren't being passed to the container. Ensure:

1. Variables are exported in the script
2. The `docker compose exec -e VAR` syntax is used (not `-e VAR=value`)

```bash
export DBUSER="value"
docker compose exec -T -e DBUSER container_name command
```

### "Passphrase incorrect"

The passphrase in Vault doesn't match the repository. Either:

- Vault has wrong passphrase → update Vault
- Repository wasn't updated → run `borg key change-passphrase`

### ntfy 401 Unauthorized

The borgmatic config still has a hardcoded token instead of the environment variable:

```yaml
# Wrong
access_token: hardcoded-token

# Correct
access_token: ${NTFY_ACCESS_TOKEN}
```

---

## Security Best Practices

1. **Least Privilege:** Each service gets its own AppRole with access only to its secrets
2. **Short TTLs:** Use short token TTLs (1h) to limit exposure if compromised
3. **Secure Storage:** Store vault-approle.env with `chmod 600`
4. **Audit Logging:** Enable Vault audit logging to track secret access
5. **Key Backup:** Always export and securely store borg paper keys
6. **Rotation:** Rotate borg passphrases periodically and after any suspected compromise
7. **IP Binding:** Use CIDR restrictions for internal servers where possible
