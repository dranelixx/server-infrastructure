<!-- LAST EDITED: 2026-02-07 -->

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
└── network-bridge/   # Network abstraction (deferred - not yet implemented)
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

### Versioning

Modules are referenced by relative path and versioned via annotated Git tags:

```hcl
source = "../../modules/proxmox-vm"  # Relative path (no git:: source pinning)
```text

**Why relative paths instead of `git::` source refs:**

- No network dependency during `terraform init` (self-hosted runner in private network)
- Instant feedback when developing modules locally
- Single-user project: version pinning overhead not justified
- Git tags serve as documented milestones for rollback and diffing

**Tag format:** `modules/<module-name>/v<MAJOR>.<MINOR>.<PATCH>`

Examples:

- `modules/proxmox-vm/v1.0.0`
- `modules/proxmox-lxc/v1.0.0`

**Semantic versioning rules:**

- PATCH: Bug fixes (no interface changes)
- MINOR: New optional features, deprecations
- MAJOR: Breaking changes (removed variables, changed behavior)

**Deprecation strategy:** Deprecate in MINOR, remove in next MAJOR.

**Useful commands:**

```bash
# List all versions of a module
git tag -l "modules/proxmox-vm/*"

# Diff between two versions
git diff modules/proxmox-vm/v1.0.0..modules/proxmox-vm/v2.0.0 -- terraform/modules/proxmox-vm/
```text

### Registry Publishing (Future)

Modules could be published to Terraform Registry for other Proxmox users, but currently they're
too specific to this setup. Would need generalization first. Existing Git tags provide a migration
path if registry publishing is pursued later.

## Alternatives Considered

| Alternative               | Why Not Chosen                                |
| ------------------------- | --------------------------------------------- |
| Inline resources          | Code duplication, maintenance nightmare       |
| Terragrunt                | Additional tool, complexity for current scale |
| Separate module repo      | Overhead for single-user project              |
| Copy-paste with variables | Still duplication, easy to diverge            |
````
