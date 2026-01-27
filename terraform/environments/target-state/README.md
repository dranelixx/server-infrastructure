<!-- LAST EDITED: 2026-01-10 -->

# Target State Environment

**Post-Migration Architecture** with HP 1910-24G Switch, VLAN Segmentation and LACP Bonding.

## Architecture

### Network Design

- **VLAN 10** (Management): Proxmox Hosts, iLOs, Switch Management
- **VLAN 20** (Production): Publicly accessible services (Plex, Nextcloud)
- **VLAN 30** (Compute): Internal services (TrueNAS, Docker, arr-stack)
- **vmbr_storage**: Internal L2 Bridge (TrueNAS ↔ Plex ↔ arr-stack)

### Multi-homed VMs

| VM            | net0 (VLAN)             | net1 (vmbr_storage) | Purpose                               |
| ------------- | ----------------------- | ------------------- | ------------------------------------- |
| **TrueNAS**   | 10.0.30.20/24 (VLAN 30) | 10.10.10.1/24       | NFS/SMB Management + Storage Serving  |
| **Plex**      | 10.0.20.30/24 (VLAN 20) | 10.10.10.2/24       | External Access + Media from TrueNAS  |
| **arr-stack** | 10.0.30.90/24 (VLAN 30) | 10.10.10.3/24       | Download Management + Move to TrueNAS |

**Advantage:** Storage traffic (TrueNAS ↔ Plex) runs over virtual bridge → Multi-Gbps bandwidth (no physical NIC limit).

## Usage

### 1. Configure Variables

```bash
# Copy example file
cp ../../terraform.tfvars.example terraform.tfvars

# Edit credentials (NEVER commit terraform.tfvars!)
vim terraform.tfvars
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Show Plan

```bash
terraform plan
```

### 4. Apply (WARNING: Modifies real infrastructure!)

```bash
terraform apply
```

## Outputs

### Ansible Inventory

```bash
# Generate JSON for Ansible
terraform output -json vm_inventory > ../../../ansible/inventory/terraform_outputs.json

# Test Ansible inventory
cd ../../../ansible
./inventory/scripts/terraform_inventory.py --list
```

### VLAN Assignments

```bash
terraform output vlan_assignments
```

### Infrastructure Summary

```bash
terraform output infrastructure_summary
```

## VM Details

| VMID | Name                  | vCPU | RAM  | VLAN | Multi-homed | Ansible Role |
| ---- | --------------------- | ---- | ---- | ---- | ----------- | ------------ |
| 4000 | truenas-prod-cz-01    | 6    | 32GB | 30   | ✅          | truenas      |
| 1000 | pms-prod-cz-01        | 10   | 24GB | 20   | ✅          | plex         |
| 1100 | the-arr-stack-prod-01 | 8    | 8GB  | 30   | ✅          | arr-stack    |
| 8000 | nextcloud-prod-cz-01  | 12   | 8GB  | 20   | ❌          | nextcloud    |
| 2000 | docker-prod-cz-01     | 12   | 12GB | 30   | ❌          | docker-host  |

**Total Resources:** 48 vCPUs, 84GB RAM

## Migration from Current to Target State

See [Migration Plan](../../../docs/architecture/03%20-%20Migration%20Plan.md)
for detailed migration steps.

**Critical Changes:**

- ✅ VLANs 10/20/30 instead of flat network 10.0.1.0/24
- ✅ Multi-homed VMs (2 NICs)
- ✅ vmbr_storage for high-throughput storage traffic
- ✅ LACP bond on Loki (eno1-4)
