# Proxmox Provider Variables (bpg/proxmox)
# IMPORTANT: Never commit terraform.tfvars with real credentials!

variable "proxmox_api_url" {
  description = "Proxmox API endpoint (e.g., https://10.0.30.10:8006/ - NO /api2/json suffix!)"
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
  description = "Skip TLS verification (use for self-signed certs)"
  type        = bool
  default     = true
}

# LXC Container Access
variable "ssh_public_keys" {
  description = "List of SSH public keys for LXC container root access"
  type        = list(string)
  default     = []
}
