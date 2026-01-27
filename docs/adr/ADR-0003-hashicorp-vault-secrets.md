<!-- LAST EDITED: 2026-01-27 -->

# ADR-0003: HashiCorp Vault for Secrets Management

## Status

Accepted

## Context

Infrastructure automation requires storing sensitive credentials (API tokens, passwords, SSH keys).
Options for secrets management range from simple (environment variables, encrypted files) to
enterprise solutions (HashiCorp Vault, AWS Secrets Manager).

## Decision

Use HashiCorp Vault as the centralized secrets management solution with AppRole authentication
for CI/CD pipelines.

### Bootstrap Strategy

GitHub Secrets store only Vault credentials (`VAULT_ADDR`, `VAULT_ROLE_ID`, `VAULT_SECRET_ID`).
All other secrets are fetched from Vault at runtime.

### Why not store everything in GitHub Secrets?

The bootstrap problem cannot be eliminated - something must provide initial Vault access. However,
the **blast radius** differs significantly:

| Scenario           | GitHub Secrets Only                 | Vault with Bootstrap                 |
| ------------------ | ----------------------------------- | ------------------------------------ |
| GitHub compromised | All secrets exposed, no audit trail | Only Vault credentials exposed       |
| Revocation         | Manual rotation of each secret      | Single point to revoke all access    |
| Audit              | Limited visibility                  | Full audit logs of who accessed what |
| Dynamic secrets    | Not possible                        | Secrets can auto-expire after use    |

### Why not Ansible Vault?

Ansible Vault encrypts files statically in the repository:

- No rotation without re-encrypting and committing
- No audit trail of access
- No central revocation
- Secrets live in Git history forever

HashiCorp Vault provides dynamic secrets, automatic expiration, and enterprise-grade audit logging.

## Consequences

### Positive

- Centralized secret management with audit logs
- Dynamic secrets with automatic lease expiration
- Single point for emergency revocation
- Demonstrates enterprise patterns in portfolio

### Negative

- Additional infrastructure to maintain (Vault server)
- Learning curve for Vault concepts
- Single point of failure if Vault is unavailable

### Mitigations

- Vault backup strategy with automated snapshots
- Unseal keys stored securely outside infrastructure
- Recovery runbook documented

## Alternatives Considered

| Alternative         | Why Not Chosen                                      |
| ------------------- | --------------------------------------------------- |
| GitHub Secrets only | No audit, no dynamic secrets, no central revocation |
| Ansible Vault       | Static encryption, secrets in Git history           |
| SOPS                | Good for GitOps, but no dynamic secrets or audit    |
| AWS Secrets Manager | Vendor lock-in, costs scale with usage              |
