# Hetzner Environment Outputs

output "server_info" {
  description = "Hetzner Cloud VPS details"
  value = {
    name        = hcloud_server.vps.name
    ipv4        = hcloud_server.vps.ipv4_address
    ipv6        = hcloud_server.vps.ipv6_address
    server_type = hcloud_server.vps.server_type
    location    = hcloud_server.vps.location
    status      = hcloud_server.vps.status
    labels      = hcloud_server.vps.labels
  }
}

output "storage_box_info" {
  description = "Hetzner Storage Box details"
  value = {
    name     = hcloud_storage_box.backup.name
    server   = hcloud_storage_box.backup.server
    username = hcloud_storage_box.backup.username
    type     = hcloud_storage_box.backup.storage_box_type
    location = hcloud_storage_box.backup.location
  }
}

output "firewall_info" {
  description = "Hetzner Cloud Firewall details"
  value = {
    name       = hcloud_firewall.main.name
    rule_count = length(hcloud_firewall.main.rule)
    labels     = hcloud_firewall.main.labels
  }
}

output "infrastructure_summary" {
  description = "Hetzner infrastructure overview"
  value = {
    vps_count         = 1
    storage_box_count = 1
    firewall_count    = 1
    vps_location      = hcloud_server.vps.location
    vps_type          = hcloud_server.vps.server_type
  }
}
