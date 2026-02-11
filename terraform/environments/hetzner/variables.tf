# Hetzner Cloud Provider Variables
# IMPORTANT: Never commit terraform.tfvars with real credentials!

variable "hcloud_token" {
  description = "Hetzner Cloud API token for provider authentication"
  type        = string
  sensitive   = true
}

variable "storage_box_password" {
  description = "Hetzner Storage Box password (CIFS/SSH access)"
  type        = string
  sensitive   = true
}
