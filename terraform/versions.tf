terraform {
  required_version = ">= 1.7.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 3.0"
    }
  }
}
