# Combined Policy for Vault Agent on pms-prod-cz-01
# Allows read access to all service secrets on this specific host

path "secret/data/prod/services/pms-prod-cz-01/*" {
  capabilities = ["read"]
}
