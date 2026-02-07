# Proxmox Provider Variables
# IMPORTANT: Never commit terraform.tfvars with real credentials!

variable "proxmox_api_url" {
  description = "Proxmox API URL (e.g., https://<PROXMOX_HOST>:8006/api2/json)"
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
  description = "Proxmox API Token ID (e.g., root@pam!claude)"
  type        = string
  default     = null
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
  default     = null
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (should be false when using HAProxy with valid certs)"
  type        = bool
  default     = false
}
