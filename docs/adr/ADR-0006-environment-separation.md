<!-- LAST EDITED: 2026-01-27 -->

# ADR-0006: Environment Separation Strategy

## Status

Accepted

## Context

The infrastructure is undergoing a migration from a flat network (Dell switch) to a segmented
VLAN setup (HP switch). Both configurations need to coexist during the transition period.

## Decision

Use two separate Terraform directories instead of workspaces or branches:

````text
terraform/environments/
├── current-state/    # Dell switch, flat network (production)
└── target-state/     # HP switch, VLANs (prepared, not deployed)
```text

Both environments share the same modules via relative paths:

```hcl
module "vm" {
  source = "../../modules/proxmox-vm"
}
```text

### Migration Strategy

1. Map existing infrastructure in `current-state`
2. Copy and modify for `target-state` with VLAN configuration
3. Validate `target-state` with `terraform plan`
4. Physical switch installation in colocation
5. Apply `target-state` during maintenance window
6. Archive `current-state` (keep for reference, mark deprecated)

## Consequences

### Positive

- Clear separation between current and future state
- No risk of accidentally applying target-state to production
- Both states can be validated independently
- Easy comparison between configurations
- Rollback possible (current-state remains intact until cutover)

### Negative

- Code duplication between environments
- Changes to shared logic must be made in modules, not environments
- Two state files to manage

### Why not Terraform Workspaces?

Workspaces are designed for **identical code** in different environments (dev/staging/prod),
not for **different configurations** during a migration. Using workspaces would require complex
conditionals throughout the code:

```hcl
# This is what we're avoiding:
vlan_tag = terraform.workspace == "target" ? 20 : null
```text

Separate directories make the differences explicit and reviewable.

## Alternatives Considered

| Alternative           | Why Not Chosen                                       |
| --------------------- | ---------------------------------------------------- |
| Terraform workspaces  | Wrong tool for migration (identical code assumption) |
| Git branches          | Merge conflicts, hard to compare side-by-side        |
| Feature flags in code | Complex conditionals, hard to reason about           |
| Blue/green with DNS   | Network-level change, not just application           |
````
