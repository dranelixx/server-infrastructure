<!-- LAST EDITED: 2026-02-12 -->

# ADR-0005: Terraform State Backend Migration

## Status

Implemented (2026-02-09)

## Context

Terraform state must be stored remotely for team collaboration and CI/CD access. Currently using
Terraform Cloud (HCP), but pricing changes make this unsustainable.

### Pricing Change

- Terraform Cloud Free Tier ends **2026-03-31**
- New RUM (Resource Under Management) pricing: ~$0.10 USD per resource/month
- At 200+ resources: $20-50 USD/month
- S3 equivalent: <$0.20 EUR/month

## Decision

Migrate to a hybrid S3 backend:

| Component | Purpose                      | Location                       |
| --------- | ---------------------------- | ------------------------------ |
| Primary   | Production state             | S3 in Frankfurt (eu-central-1) |
| DR/Dev    | Backup and local development | MinIO on TrueNAS               |

### Why S3?

- **Cost**: Orders of magnitude cheaper than Terraform Cloud
- **Native locking**: Since Terraform 1.10, `use_lockfile = true` enables S3-native locks
  (DynamoDB no longer required)
- **EU data residency**: State stays in Frankfurt
- **No vendor lock-in**: S3 API is a standard, works with MinIO, Cloudflare R2, etc.
- **OpenTofu compatible**: No proprietary features

### Why MinIO as secondary?

- Demonstrates self-hosting skills
- S3-compatible API for consistent tooling
- Provides disaster recovery option
- Enables offline/local development

## Consequences

### Positive

- Dramatically reduced costs (~$50/month → ~$0.20/month)
- EU data residency for compliance
- No vendor lock-in
- Self-hosted backup option

### Negative

- Lose Terraform Cloud features (run history UI, cost estimation, Sentinel)
- Must manage S3 bucket and permissions
- No built-in run approval workflow (use GitHub Environment protection instead)

### Authentication Update (2026-02-12)

S3 backend authentication was migrated from long-lived IAM access keys (`terraform-state-manager`
user) to GitHub OIDC federation. CI/CD workflows now obtain temporary STS credentials via
`aws-actions/configure-aws-credentials@v4`, eliminating static AWS secrets. The IAM Role ARN is
stored in Vault (`secret/shared/ci-cd/aws role_arn`) for consistency with the existing secrets
management pattern (see [ADR-0003](ADR-0003-hashicorp-vault-secrets.md)).

## Alternatives Considered

| Alternative                      | Why Not Chosen                                    |
| -------------------------------- | ------------------------------------------------- |
| Stay on Terraform Cloud          | Cost prohibitive at scale                         |
| GitLab-managed state             | Requires GitLab migration                         |
| Spacelift/env0                   | Still vendor lock-in, costs                       |
| Self-hosted Terraform Enterprise | Overkill, expensive license                       |
| Pure MinIO                       | Single point of failure, no geographic redundancy |
