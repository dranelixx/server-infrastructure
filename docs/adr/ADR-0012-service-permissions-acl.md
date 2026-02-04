<!-- LAST EDITED: 2026-02-04 -->

# ADR-0012: Service Directory Permissions with POSIX ACLs

## Status

Accepted

## Context

Services require a permission model that balances security, operations, and isolation. The key
security question: **What happens if an attacker gains access to my admin user session?**

Traditional Unix permissions (owner/group/other) force a binary choice between convenience
(admin can read everything) and security (sudo required for everything). Neither is ideal.

## Decision

Use POSIX Access Control Lists (ACLs) to implement granular, defense-in-depth permissions.

### Security Model

**Threat model**: Attacker compromises admin user session (stolen SSH key, session hijack).

**Goal**: Secrets should NOT be accessible without additional authentication (sudo password).

**Attack path with this model**:

```text
VPN Access → SSH Key → (Key Passphrase) → sudo password → Secrets
```

Each arrow is an additional barrier. Without all four, secrets remain protected.

### Why Not Just Use sudo for Everything?

| Approach             | Security | Convenience | Reasoning                                 |
| -------------------- | -------- | ----------- | ----------------------------------------- |
| Admin reads all      | Low      | High        | Compromised session = all secrets exposed |
| sudo for everything  | Medium   | Low         | Password cache (15min) weakens protection |
| ACLs (this decision) | High     | Medium      | Secrets protected, non-secrets accessible |

The sudo password cache means an active attacker could wait for a cached session. ACLs ensure
secrets are NEVER readable without explicit sudo, regardless of cache state.

### Permission Layers

**Layer 1 - Directory access**: Admin can navigate, see structure, read docker-compose.yml

**Layer 2 - Config subdirectories**: Admin can list contents, see logs

**Layer 3 - Secret files**: Only root and service user can read (.env, config.yml with tokens)

### ACL Structure

| Resource                 | vault   | admin | service-user | Rationale                        |
| ------------------------ | ------- | ----- | ------------ | -------------------------------- |
| `/srv/{service}/`        | rwx     | rwx   | r-x          | Navigation and non-secret files  |
| `/srv/{service}/config/` | rwx     | r-x   | rwx          | Service writes logs, admin reads |
| Secret files             | (owner) | ---   | r--          | Secrets require sudo to read     |

### Implementation Reference (pms-prod-cz-01)

1. **Dedicated system users** per service (UID 3001-3008):

   ```bash
   useradd --system --uid 3005 --no-create-home --shell /usr/sbin/nologin overlay-reset
   ```

2. **Directory ACLs** with inheritance via defaults:

   ```bash
   setfacl -m u:vault:rwx,u:admin:rwx /srv/{service}
   setfacl -dm u:{service-user}:rx /srv/{service}
   ```

3. **Vault Agent** renders secrets and sets explicit read-only ACL for service user:

   ```hcl
   template {
     destination = "/srv/{service}/.env"
     perms       = "0640"
     command     = "setfacl -m u:{uid}:r /srv/{service}/.env"
   }
   ```

## Consequences

### Positive

- Compromised admin session cannot read secrets without sudo
- Daily operations (logs, docker-compose, debugging) work without sudo
- Each service isolated to dedicated user
- Flexible - can be stricter or more relaxed per host based on threat model

### Negative

- ACLs add complexity over simple chmod
- Requires understanding of mask and default ACLs
- Some tools (NFS, certain backup solutions) handle ACLs poorly

## Alternatives Considered

| Alternative          | Why Not Chosen                                    |
| -------------------- | ------------------------------------------------- |
| sudo for everything  | Password cache undermines security, high friction |
| Shared service group | All services share access, reduced isolation      |
| No admin ACL at all  | Requires sudo even for logs and docker-compose    |
| Docker secrets       | Only works in Swarm mode, not standalone compose  |
| No restrictions      | Single SSH key compromise exposes all secrets     |
