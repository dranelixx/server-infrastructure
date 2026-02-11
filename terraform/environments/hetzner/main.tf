# Hetzner Cloud - VPS, Storage Box, and Firewall
# Maps existing Hetzner infrastructure into Terraform management

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.60"
    }
  }

  backend "s3" {
    bucket       = "getinn-terraform-state"
    key          = "environments/hetzner/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

# === Hetzner Cloud VPS ===

resource "hcloud_server" "vps" {
  name        = "debian-prod-fsn1-dc14-01"
  server_type = "cx23"
  image       = "debian-13"
  location    = "fsn1"

  delete_protection  = true
  rebuild_protection = true # Must match delete_protection

  firewall_ids = [hcloud_firewall.main.id]

  labels = {
    server     = "prod"
    managed_by = "terraform"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# === Hetzner Cloud Firewall ===

resource "hcloud_firewall" "main" {
  name = "firewall-1"

  # ICMP (ping)
  rule {
    description = "ICMP"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # SSH
  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # HTTP
  rule {
    description = "HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  rule {
    description = "HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  # Coolify
  rule {
    description = "Coolify"
    direction   = "in"
    protocol    = "tcp"
    port        = "8000"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  labels = {
    managed_by = "terraform"
  }
}

# === Hetzner Storage Box ===

resource "hcloud_storage_box" "backup" {
  name             = "backup-storage-box-01"
  storage_box_type = "bx21"
  location         = "fsn1"
  password         = var.storage_box_password

  delete_protection = true

  access_settings = {
    reachable_externally = true
    samba_enabled        = false
    ssh_enabled          = true
    webdav_enabled       = false
    zfs_enabled          = false
  }

  snapshot_plan = {
    hour          = 0
    minute        = 0
    max_snapshots = 10
  }

  labels = {
    brog        = "prod"
    storage-box = "prod"
    managed_by  = "terraform"
  }

  lifecycle {
    prevent_destroy = true
    # ssh_keys: ForceNew since v1.58.0 - changes trigger destroy+recreate (DATA LOSS)
    # password: Prevent unintended password changes on imported resource
    ignore_changes = [ssh_keys, password]
  }
}
