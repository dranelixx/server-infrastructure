# Terraform Cloud Backend Configuration
# Provides remote state storage, locking, and collaboration

terraform {
  cloud {
    organization = "YOUR-ORG-NAME" # Replace with your Terraform Cloud org

    workspaces {
      tags = ["server-infrastructure", "proxmox"]
    }
  }
}

# Alternative: S3 Backend (for self-hosted)
# terraform {
#   backend "s3" {
#     bucket         = "terraform-state-server-infra"
#     key            = "prod/terraform.tfstate"
#     region         = "eu-central-1"
#     encrypt        = true
#     dynamodb_table = "terraform-locks"
#   }
# }

# Alternative: Local Backend (for testing only - NOT recommended for production)
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
