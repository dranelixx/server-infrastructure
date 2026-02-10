<!-- LAST EDITED: 2026-02-10 -->

# ADR-0013: Least-Privilege Proxmox API Token for CI/CD

## Status

Accepted

## Context

The GitHub Actions runner uses a Proxmox API token (`terraform@pve!tf-automation`) created with `--privsep 0`,
meaning the token inherits **all privileges** of the `terraform@pve` user. The assigned role `TerraformAutomation`
also includes unnecessary privileges like `Sys.Modify`, `Sys.Console`, and `Pool.Allocate`.

A compromised token (e.g., via GitHub breach, log leak, or malicious dependency) could:

- Modify system settings (DNS, time, network)
- Access the Proxmox console
- Create/modify resource pools
- Perform actions far beyond what Terraform requires

This violates the principle of least privilege (see [ADR-0003](ADR-0003-hashicorp-vault-secrets.md) blast radius
minimization).

## Decision

### 1. Create a minimal role `TerraformCI` with only required privileges

| Privilege                 | Reason                                                     |
| ------------------------- | ---------------------------------------------------------- |
| `VM.Allocate`             | Create/delete VMs and LXC containers                       |
| `VM.Config.CPU`           | CPU configuration (cores, sockets, type, numa)             |
| `VM.Config.Memory`        | Memory configuration (dedicated, balloon)                  |
| `VM.Config.Disk`          | Disk configuration (multi-disk, EFI disk)                  |
| `VM.Config.Network`       | Network configuration (multi-NIC, VLAN)                    |
| `VM.Config.Options`       | Boot order, protection, tags, description, SCSI controller |
| `VM.Config.Cloudinit`     | Cloud-init IP/gateway configuration                        |
| `VM.Config.HWType`        | BIOS (ovmf/seabios), machine type (q35), agent, keyboard   |
| `VM.Audit`                | Read VM/LXC configuration (plan/refresh)                   |
| `VM.PowerMgmt`            | Start/stop VMs (started, start_on_boot)                    |
| `VM.Monitor`              | QEMU monitor commands (provider uses internally)           |
| `Datastore.AllocateSpace` | Allocate disk storage                                      |
| `Datastore.Audit`         | Read storage information                                   |
| `Sys.Audit`               | Read node information (provider requires this)             |
| `SDN.Audit`               | Read network/bridge information                            |

### 2. Use `--privsep 1` (privilege separation enabled)

The token gets **only** the explicitly assigned privileges, not the full user privileges.

### 3. Keep ACL at root path `/`

The bpg/proxmox provider queries `/cluster/resources` and `/nodes` during init, which requires `Sys.Audit` at root
level. Node-level scoping would break these calls. Security comes from the reduced privilege set, not the path.

### Removed Privileges

| Privilege         | Why removed                                                      |
| ----------------- | ---------------------------------------------------------------- |
| `Sys.Modify`      | Modifies system settings (DNS, time) - Terraform never does this |
| `Sys.Console`     | Console access - CI/CD does not need a console                   |
| `Pool.Allocate`   | Resource pool management - not used                              |
| `VM.Config.CDROM` | CD-ROM configuration - not used                                  |
| `VM.Clone`        | Template cloning - not currently used (add back if needed)       |

## PCI Passthrough Limitation

PCI passthrough (`hostpci` with device ID) requires `root@pam` username/password authentication and is
**incompatible with API tokens**. This is acceptable because:

- `hostpci` is in `lifecycle { ignore_changes }` - Terraform never modifies it after creation
- Future PCI assignments should use Proxmox Resource Mappings (`Mapping.Use` + `Mapping.Audit`)

## Consequences

### Positive

- Blast radius of a compromised token is limited to VM/LXC management
- No system-level access (DNS, time, console, pools)
- `--privsep 1` prevents privilege creep if the user gets additional roles
- Token permissions are explicit and auditable

### Negative

- Must manually add privileges if new Terraform resources need them (e.g., `VM.Clone` for template cloning)
- Provider upgrades may require privilege adjustments (check changelogs)

### Neutral

- No workflow changes needed - token values come from Vault, only the Vault secret is updated
- Old token and role should be removed after successful verification
