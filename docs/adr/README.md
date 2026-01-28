<!-- LAST EDITED: 2026-01-28 -->

# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records for the server-infrastructure project.

## What is an ADR?

An ADR documents a significant architectural decision, including the context, the decision itself,
and its consequences. ADRs help future maintainers understand why certain choices were made.

## ADR Index

| ID                                                | Title                             | Status   | Date       |
| ------------------------------------------------- | --------------------------------- | -------- | ---------- |
| [ADR-0001](ADR-0001-self-hosted-github-runner.md) | Self-hosted GitHub Runner         | Accepted | 2026-01-27 |
| [ADR-0002](ADR-0002-vlan-network-segmentation.md) | VLAN Network Segmentation         | Accepted | 2026-01-27 |
| [ADR-0003](ADR-0003-hashicorp-vault-secrets.md)   | HashiCorp Vault for Secrets       | Accepted | 2026-01-27 |
| [ADR-0004](ADR-0004-bpg-proxmox-provider.md)      | bpg/proxmox Terraform Provider    | Accepted | 2026-01-27 |
| [ADR-0005](ADR-0005-terraform-state-backend.md)   | Terraform State Backend Migration | Accepted | 2026-01-27 |
| [ADR-0006](ADR-0006-environment-separation.md)    | Environment Separation Strategy   | Accepted | 2026-01-27 |
| [ADR-0007](ADR-0007-lxc-vs-vm-placement.md)       | LXC vs VM Workload Placement      | Accepted | 2026-01-27 |
| [ADR-0008](ADR-0008-backup-strategy.md)           | Backup Strategy                   | Accepted | 2026-01-27 |
| [ADR-0009](ADR-0009-modular-terraform.md)         | Modular Terraform Structure       | Accepted | 2026-01-27 |
| [ADR-0010](ADR-0010-cicd-strategy.md)             | CI/CD Strategy                    | Accepted | 2026-01-27 |
| [ADR-0011](ADR-0011-server-hardening-baseline.md) | Server Hardening Baseline         | Accepted | 2026-01-28 |

## ADR Template

```markdown
# ADR-XXXX: Title

## Status

Accepted | Superseded | Deprecated

## Context

What is the issue that we're seeing that motivates this decision?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

What becomes easier or harder because of this change?

## Alternatives Considered

What other options were evaluated?
```

## References

- [ADR-QUESTIONS.md](ADR-QUESTIONS.md) - Original questions and answers used to create these ADRs
