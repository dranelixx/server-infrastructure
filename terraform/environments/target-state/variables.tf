# Proxmox Provider Variables (bpg/proxmox)
# IMPORTANT: Never commit terraform.tfvars with real credentials!

variable "proxmox_api_url" {
  description = "Proxmox API endpoint (e.g., https://pve.example.com/ - use HAProxy domain, NO /api2/json suffix!)"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox user (legacy auth, optional if using API token)"
  type        = string
  default     = null
}

variable "proxmox_password" {
  description = "Proxmox password (legacy auth, optional if using API token)"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID (e.g., terraform@pam!github-actions)"
  type        = string
  default     = null
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret (combined with token_id as 'ID=SECRET')"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (should be false when using HAProxy with valid certs)"
  type        = bool
  default     = false
}
