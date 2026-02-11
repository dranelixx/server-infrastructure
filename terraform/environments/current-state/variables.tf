# Proxmox Provider Variables (bpg/proxmox)
# IMPORTANT: Never commit terraform.tfvars with real credentials!

variable "proxmox_api_url" {
  description = "Proxmox API endpoint (e.g., https://pve.example.com/ - use HAProxy domain, NO /api2/json suffix!)"
  type        = string
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID (e.g., terraform@pam!github-actions)"
  type        = string
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret (combined with token_id as 'ID=SECRET')"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification (should be false when using HAProxy with valid certs)"
  type        = bool
  default     = false
}

# LXC Container Access
variable "ssh_public_keys" {
  description = "List of SSH public keys for LXC container root access"
  type        = list(string)
  default     = []
}
