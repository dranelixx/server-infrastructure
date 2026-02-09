provider "proxmox" {
  # Proxmox API Endpoint
  pm_api_url = var.proxmox_api_url

  # Authentication
  pm_user             = var.proxmox_user
  pm_password         = var.proxmox_password
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret

  # TLS Settings
  pm_tls_insecure = var.proxmox_tls_insecure

  # Performance Settings
  pm_timeout  = 600
  pm_parallel = 10

  # Logging (for debugging)
  pm_log_enable = true
  pm_log_file   = "terraform-plugin-proxmox.log"
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}
