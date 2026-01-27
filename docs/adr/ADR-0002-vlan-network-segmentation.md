<!-- LAST EDITED: 2026-01-27 -->

# ADR-0002: VLAN Network Segmentation

## Status

Accepted (implementation pending hardware installation)

## Context

The current infrastructure uses a flat network where all VMs and LXCs share the same broadcast
domain. This creates security risks:

- No isolation between workloads
- Lateral movement is trivial if any container is compromised
- Management interfaces are reachable from all systems

## Decision

Implement VLAN segmentation with three zones:

| VLAN | Name       | Purpose                | Subnet       |
| ---- | ---------- | ---------------------- | ------------ |
| 10   | Management | Proxmox, pfSense, IPMI | 10.0.10.0/24 |
| 20   | Production | User-facing services   | 10.0.20.0/24 |
| 30   | Compute    | Internal workloads     | 10.0.30.0/24 |

Inter-VLAN traffic will be routed through pfSense with firewall rules enforcing access policies.

### Hardware Requirement

This requires replacing the Dell PowerConnect 2824 with the HP 1910-24G switch:

- Dell switch is "Web-Smart" with limited functionality, no full LACP support
- Dell switch management interface is currently unreachable (Port 24 physically occupied)
- HP 1910-24G is a fully managed switch with 802.1Q VLAN and LACP support

## Consequences

### Positive

- Management traffic completely isolated from workloads
- Production services only reach what they need
- Compute workloads cannot directly access critical infrastructure
- Firewall logs provide visibility into cross-segment traffic

### Negative

- Requires physical visit to colocation to install HP switch
- More complex network configuration
- Debugging network issues requires understanding VLAN topology

## Alternatives Considered

| Alternative                        | Why Not Chosen                                      |
| ---------------------------------- | --------------------------------------------------- |
| Keep flat network + host firewalls | No central visibility, each host must be configured |
| Software-defined networking (OVN)  | Overkill for current scale, adds complexity         |
| Micro-segmentation per VM          | Management overhead too high                        |
