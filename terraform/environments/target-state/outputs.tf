# Target State Outputs
# For Ansible Dynamic Inventory Generation

# === VM Inventory for Ansible ===

output "vm_inventory" {
  description = "VM inventory for Ansible dynamic inventory script"
  value = {
    truenas = {
      vmid         = module.truenas.vmid
      ip           = module.truenas.ipv4_address
      ansible_role = "truenas"
      vlan         = 30
      multi_homed  = true
      tags         = module.truenas.tags
    }

    plex = {
      vmid         = module.plex.vmid
      ip           = module.plex.ipv4_address
      ansible_role = "plex"
      vlan         = 20
      multi_homed  = true
      tags         = module.plex.tags
    }

    arr_stack = {
      vmid         = module.arr_stack.vmid
      ip           = module.arr_stack.ipv4_address
      ansible_role = "arr-stack"
      vlan         = 30
      multi_homed  = true
      tags         = module.arr_stack.tags
    }

    nextcloud = {
      vmid         = module.nextcloud.vmid
      ip           = module.nextcloud.ipv4_address
      ansible_role = "nextcloud"
      vlan         = 20
      multi_homed  = false
      tags         = module.nextcloud.tags
    }

    docker_prod = {
      vmid         = module.docker_prod.vmid
      ip           = module.docker_prod.ipv4_address
      ansible_role = "docker-host"
      vlan         = 30
      multi_homed  = false
      tags         = module.docker_prod.tags
    }
  }
}

# === VLAN Assignments ===

output "vlan_assignments" {
  description = "VLAN assignments for network documentation"
  value = {
    vlan_10_management = [] # No VMs directly on Management VLAN

    vlan_20_production = [
      module.plex.name,
      module.nextcloud.name
    ]

    vlan_30_compute = [
      module.truenas.name,
      module.arr_stack.name,
      module.docker_prod.name
    ]

    vmbr_storage = [
      module.truenas.name,
      module.plex.name,
      module.arr_stack.name
    ]
  }
}

# === Summary Statistics ===

output "infrastructure_summary" {
  description = "Infrastructure resource summary"
  value = {
    total_vms = 5

    total_cores = (
      module.truenas.resource_specs.cores +
      module.plex.resource_specs.cores +
      module.arr_stack.resource_specs.cores +
      module.nextcloud.resource_specs.cores +
      module.docker_prod.resource_specs.cores
    )

    total_memory_mb = (
      module.truenas.resource_specs.memory +
      module.plex.resource_specs.memory +
      module.arr_stack.resource_specs.memory +
      module.nextcloud.resource_specs.memory +
      module.docker_prod.resource_specs.memory
    )

    multi_homed_vms = 3
  }
}
