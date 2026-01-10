# Current State (IST) Outputs

output "vm_inventory" {
  description = "VM inventory for Ansible dynamic inventory script (Current State)"
  value = {
    truenas = {
      vmid         = module.truenas.vmid
      name         = module.truenas.name
      ip           = module.truenas.ipv4_address
      ansible_role = "truenas"
      vlan         = null # Flat network
      multi_homed  = false
      tags         = module.truenas.tags
      target_node  = module.truenas.target_node
    }
    pms = {
      vmid         = module.pms.vmid
      name         = module.pms.name
      ip           = module.pms.ipv4_address
      ansible_role = "plex"
      vlan         = null
      multi_homed  = false
      tags         = module.pms.tags
      target_node  = module.pms.target_node
    }
    arr_stack = {
      vmid         = module.arr_stack.vmid
      name         = module.arr_stack.name
      ip           = module.arr_stack.ipv4_address
      ansible_role = "arr_stack"
      vlan         = null
      multi_homed  = false
      tags         = module.arr_stack.tags
      target_node  = module.arr_stack.target_node
    }
    docker_prod = {
      vmid         = module.docker_prod.vmid
      name         = module.docker_prod.name
      ip           = module.docker_prod.ipv4_address
      ansible_role = "docker"
      vlan         = null
      multi_homed  = false
      tags         = module.docker_prod.tags
      target_node  = module.docker_prod.target_node
    }
    nextcloud = {
      vmid         = module.nextcloud.vmid
      name         = module.nextcloud.name
      ip           = module.nextcloud.ipv4_address
      ansible_role = "nextcloud"
      vlan         = null
      multi_homed  = false
      tags         = module.nextcloud.tags
      target_node  = module.nextcloud.target_node
    }
  }
}

output "network_summary" {
  description = "Current network configuration summary"
  value = {
    network_type = "Flat (No VLANs)"
    subnet       = "10.0.1.0/24"
    gateway      = "10.0.1.1"
    switch       = "Dell PowerConnect 2824"
    vlans        = []
  }
}

output "infrastructure_summary" {
  description = "Current infrastructure overview"
  value = {
    total_vms     = 5
    total_cores   = module.truenas.resource_specs.cores + module.pms.resource_specs.cores + module.arr_stack.resource_specs.cores + module.docker_prod.resource_specs.cores + module.nextcloud.resource_specs.cores
    total_memory  = module.truenas.resource_specs.memory + module.pms.resource_specs.memory + module.arr_stack.resource_specs.memory + module.docker_prod.resource_specs.memory + module.nextcloud.resource_specs.memory
    proxmox_nodes = ["pve-prod-cz-loki"]
  }
}

output "migration_ready" {
  description = "Indicates if infrastructure is ready for VLAN migration"
  value = {
    current_state_documented = true
    target_state_planned     = true
    next_step                = "Review migration plan (docs/architecture/03 - Migration Plan.md)"
  }
}
