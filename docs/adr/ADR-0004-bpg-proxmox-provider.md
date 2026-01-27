<!-- LAST EDITED: 2026-01-27 -->

# ADR-0004: bpg/proxmox Terraform Provider

## Status

Accepted

## Context

Terraform requires a provider to manage Proxmox resources. Two main options exist:

- `telmate/proxmox` - The original community provider
- `bpg/proxmox` - A newer, actively maintained alternative

## Decision

Use the `bpg/proxmox` provider (v0.91.0+) for all Proxmox resource management.

### Comparison

| Aspect           | bpg/proxmox                          | telmate/proxmox                                   |
| ---------------- | ------------------------------------ | ------------------------------------------------- |
| Stable releases  | 163+                                 | 48                                                |
| Current version  | Stable releases                      | RC status for months                              |
| Known issues     | Actively triaged                     | Documented panics (nil map, interface conversion) |
| Framework        | Modern Terraform Plugin Framework    | Legacy SDK                                        |
| OpenTofu         | Explicitly supported                 | Not mentioned                                     |
| Issue management | Labels, prioritization via reactions | Less structured                                   |

### Technical Reasons

- Active development with frequent releases
- Better stability (no documented panic issues)
- Modern plugin framework for better long-term support
- Explicit OpenTofu compatibility for future flexibility

## Consequences

### Positive

- Stable provider with active maintenance
- Modern features (PCI passthrough, NUMA, EFI boot)
- Good documentation and issue response times
- OpenTofu compatibility if needed

### Negative

- Different resource syntax than telmate (migration effort if switching)
- Smaller community than the original provider

## Alternatives Considered

| Alternative      | Why Not Chosen                             |
| ---------------- | ------------------------------------------ |
| telmate/proxmox  | Stability issues, stalled development      |
| Direct API calls | No state management, reinventing the wheel |
| Pulumi           | Less mature Proxmox support                |
