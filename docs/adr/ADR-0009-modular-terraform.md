<!-- LAST EDITED: 2026-01-27 -->

# ADR-0009: Modular Terraform Structure

## Status

Accepted

## Context

The infrastructure includes 5 VMs and 15 LXCs with similar configurations. Without abstraction,
each resource would require duplicated code with minor variations.

## Decision

Create reusable Terraform modules for common resource types:

````text
terraform/modules/
├── proxmox-vm/       # VM provisioning
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── proxmox-lxc/      # LXC provisioning
└── network-bridge/   # Network abstraction
```text

### Module Usage

```hcl
module "webserver" {
  source = "../../modules/proxmox-vm"

  name        = "webserver"
  target_node = "loki"
  cores       = 2
  memory      = 2048
  # ... other parameters
}
```text

### Benefits

- Single fix applies to all instances
- Consistent configuration across resources
- Self-documenting through variable descriptions
- Testable in isolation

## Consequences

### Positive

- DRY (Don't Repeat Yourself) principle
- Changes propagate automatically
- Easier to audit and review
- Enables environment separation (both use same modules)

### Negative

- Breaking changes affect all consumers
- Initial setup overhead
- Module interface must be well-designed upfront

### Versioning (TODO)

Currently, modules are referenced by relative path without versioning:

```hcl
source = "../../modules/proxmox-vm"  # No version pinning!
```text

**Planned improvement**: Introduce semantic versioning with Git tags:

- PATCH: Bug fixes
- MINOR: New optional features
- MAJOR: Breaking changes

This allows environments to pin stable versions and migrate independently.

### Registry Publishing (Future)

Modules could be published to Terraform Registry for other Proxmox users, but currently they're
too specific to this setup. Would need generalization first.

## Alternatives Considered

| Alternative               | Why Not Chosen                                |
| ------------------------- | --------------------------------------------- |
| Inline resources          | Code duplication, maintenance nightmare       |
| Terragrunt                | Additional tool, complexity for current scale |
| Separate module repo      | Overhead for single-user project              |
| Copy-paste with variables | Still duplication, easy to diverge            |
````
