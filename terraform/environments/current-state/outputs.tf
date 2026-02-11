# Current State Outputs

output "vm_inventory" {
  description = "VM inventory for Ansible dynamic inventory script (Current State)"
  value = {
    truenas = {
      vmid         = module.truenas.vmid
      name         = module.truenas.name
      ip           = module.truenas.ipv4_address
      ansible_role = "truenas"
      vlan         = null # Flat network
      multi_homed  = true
      tags         = module.truenas.tags
      target_node  = module.truenas.target_node
    }
    pms = {
      vmid         = module.pms.vmid
      name         = module.pms.name
      ip           = module.pms.ipv4_address
      ansible_role = "plex"
      vlan         = null
      multi_homed  = true
      tags         = module.pms.tags
      target_node  = module.pms.target_node
    }
    arr_stack = {
      vmid         = module.arr_stack.vmid
      name         = module.arr_stack.name
      ip           = module.arr_stack.ipv4_address
      ansible_role = "arr_stack"
      vlan         = null
      multi_homed  = true
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

output "lxc_inventory" {
  description = "LXC container inventory for Ansible dynamic inventory script (Current State)"
  value = {
    prometheus = {
      vmid        = module.prometheus.vmid
      name        = module.prometheus.name
      tags        = module.prometheus.tags
      target_node = module.prometheus.target_node
    }
    influxdbv2 = {
      vmid        = module.influxdbv2.vmid
      name        = module.influxdbv2.name
      tags        = module.influxdbv2.tags
      target_node = module.influxdbv2.target_node
    }
    vault = {
      vmid        = module.vault.vmid
      name        = module.vault.name
      tags        = module.vault.tags
      target_node = module.vault.target_node
    }
    ptero_panel = {
      vmid        = module.ptero_panel.vmid
      name        = module.ptero_panel.name
      tags        = module.ptero_panel.tags
      target_node = module.ptero_panel.target_node
    }
    ptero_wings = {
      vmid        = module.ptero_wings.vmid
      name        = module.ptero_wings.name
      tags        = module.ptero_wings.tags
      target_node = module.ptero_wings.target_node
    }
    ptero_mariadb = {
      vmid        = module.ptero_mariadb.vmid
      name        = module.ptero_mariadb.name
      tags        = module.ptero_mariadb.tags
      target_node = module.ptero_mariadb.target_node
    }
    ptero_wings_devel = {
      vmid        = module.ptero_wings_devel.vmid
      name        = module.ptero_wings_devel.name
      tags        = module.ptero_wings_devel.tags
      target_node = module.ptero_wings_devel.target_node
    }
    ptero_panel_devel = {
      vmid        = module.ptero_panel_devel.vmid
      name        = module.ptero_panel_devel.name
      tags        = module.ptero_panel_devel.tags
      target_node = module.ptero_panel_devel.target_node
    }
    ptero_panel_devel_02 = {
      vmid        = module.ptero_panel_devel_02.vmid
      name        = module.ptero_panel_devel_02.name
      tags        = module.ptero_panel_devel_02.tags
      target_node = module.ptero_panel_devel_02.target_node
    }
    netbox = {
      vmid        = module.netbox.vmid
      name        = module.netbox.name
      tags        = module.netbox.tags
      target_node = module.netbox.target_node
    }
    trilium = {
      vmid        = module.trilium.vmid
      name        = module.trilium.name
      tags        = module.trilium.tags
      target_node = module.trilium.target_node
    }
    syncthing = {
      vmid        = module.syncthing.vmid
      name        = module.syncthing.name
      tags        = module.syncthing.tags
      target_node = module.syncthing.target_node
    }
    vscode = {
      vmid        = module.vscode.vmid
      name        = module.vscode.name
      tags        = module.vscode.tags
      target_node = module.vscode.target_node
    }
    graylog = {
      vmid        = module.graylog.vmid
      name        = module.graylog.name
      tags        = module.graylog.tags
      target_node = module.graylog.target_node
    }
    github_runner = {
      vmid        = module.github_runner.vmid
      name        = module.github_runner.name
      tags        = module.github_runner.tags
      target_node = module.github_runner.target_node
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

locals {
  vm_specs = [
    module.truenas.resource_specs,
    module.pms.resource_specs,
    module.arr_stack.resource_specs,
    module.docker_prod.resource_specs,
    module.nextcloud.resource_specs,
  ]

  lxc_specs = [
    module.prometheus.resource_specs,
    module.influxdbv2.resource_specs,
    module.vault.resource_specs,
    module.ptero_panel.resource_specs,
    module.ptero_wings.resource_specs,
    module.ptero_mariadb.resource_specs,
    module.ptero_wings_devel.resource_specs,
    module.ptero_panel_devel.resource_specs,
    module.ptero_panel_devel_02.resource_specs,
    module.netbox.resource_specs,
    module.trilium.resource_specs,
    module.syncthing.resource_specs,
    module.vscode.resource_specs,
    module.graylog.resource_specs,
    module.github_runner.resource_specs,
  ]
}

output "infrastructure_summary" {
  description = "Current infrastructure overview"
  value = {
    total_vms       = length(local.vm_specs)
    vm_total_cores  = sum([for s in local.vm_specs : s.cores])
    vm_total_memory = sum([for s in local.vm_specs : s.memory])

    total_lxcs       = length(local.lxc_specs)
    lxc_total_cores  = sum([for s in local.lxc_specs : s.cores])
    lxc_total_memory = sum([for s in local.lxc_specs : s.memory])

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
