<!-- LAST EDITED: 2026-01-27 -->

# ADR-0007: LXC vs VM Workload Placement

## Status

Accepted (with pending security review)

## Context

Proxmox supports both LXC containers and full VMs. Each has different characteristics for
performance, isolation, and resource efficiency.

## Decision

### Use VMs when

- **PCI/GPU passthrough required**: Plex (hardware transcoding), TrueNAS (HBA controller)
- **Custom kernel features needed**: Docker, ZFS
- **I/O intensive workloads**: Raw disk performance matters
- **Maximum isolation required**: Security-critical workloads

### Use LXC for everything else

- Lower overhead than VMs
- Faster startup times
- Shared resources with host
- Sufficient for most services

### Current Placement

| Workload      | Type | Reason                          |
| ------------- | ---- | ------------------------------- |
| TrueNAS       | VM   | HBA passthrough for ZFS         |
| Plex          | VM   | GPU passthrough for transcoding |
| pfSense       | VM   | Network stack isolation         |
| GitHub Runner | LXC  | Standard workload               |
| Vault         | LXC  | **TODO: Should be VM**          |
| Web services  | LXC  | Standard workloads              |

## Consequences

### Positive

- Resource efficiency for most workloads
- Fast container startup
- Easy snapshotting and migration

### Negative

- LXCs share host kernel (weaker isolation than VMs)
- Privileged LXCs have security implications
- Some workloads placed incorrectly (see TODO)

### Security Review (TODO)

After further analysis, some placements need reconsideration:

1. **Vault → VM**: Secrets management deserves maximum isolation
2. **Pterodactyl Wings → VM**: Better isolation for game servers
3. **Audit all LXCs**: Check privileged vs unprivileged configuration

## Alternatives Considered

| Alternative | Why Not Chosen                         |
| ----------- | -------------------------------------- |
| All VMs     | Resource overhead, slower operations   |
| All LXCs    | Can't do passthrough, weaker isolation |
| Kubernetes  | Overkill for current scale, complexity |
| Docker only | Loses Proxmox management benefits      |
