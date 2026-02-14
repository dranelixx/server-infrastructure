<!-- LAST EDITED: 2026-02-14 -->

# ADR-0010: CI/CD Strategy

## Status

Accepted

## Context

Infrastructure changes need automated validation and controlled deployment. The CI/CD pipeline
must handle Terraform plans, applies, and drift detection while preventing concurrent modifications.

## Decision

### Workflow Structure

| Workflow              | Trigger         | Purpose                                |
| --------------------- | --------------- | -------------------------------------- |
| `terraform-plan.yml`  | Pull Request    | Validate changes, post plan as comment |
| `terraform-apply.yml` | Push to main    | Apply after manual approval            |
| `terraform-drift.yml` | Daily 06:00 UTC | Detect configuration drift             |

### Concurrency Strategies

Different workflows require different concurrency handling:

| Workflow | Strategy                    | Reason                                 |
| -------- | --------------------------- | -------------------------------------- |
| Plan     | `cancel-in-progress: true`  | New commit obsoletes old plan          |
| Apply    | `cancel-in-progress: false` | Interrupted apply = inconsistent state |
| Drift    | `cancel-in-progress: false` | Each check should complete             |

### Drift Detection via GitHub Issues

When drift is detected (exit code 2), the workflow automatically:

1. Creates or updates a GitHub Issue with label `drift-detection`
2. Includes the plan output showing differences
3. Closes the issue automatically when drift is resolved

**Why GitHub Issues instead of Slack/PagerDuty?**

- Free, no additional tools
- Directly in the repository alongside code
- Assignable, labelable, trackable
- Creates audit trail of drift events
- For solo project, email notifications from GitHub are sufficient

### Pre-commit Hooks

Extensive local hooks catch issues before push:

- `terraform fmt` - Formatting
- `terraform validate` - Syntax
- `tflint` - Best practices
- `gitleaks` - Secret detection
- `prettier` - Markdown formatting

**Why local hooks instead of CI-only?**

- Faster feedback loop
- Saves CI minutes
- Keeps Git history clean
- Developers see issues immediately

**Note**: `terraform_docs` is disabled as a pre-commit hook because it modifies files after staging.
Instead, a `Docs Check` CI job in `terraform-plan.yml` validates that module READMEs are up to date
using `terraform-docs/gh-actions@v1` with `fail-on-diff: true`.

## Consequences

### Positive

- Automated validation prevents broken deployments
- Manual approval gate for production changes
- Drift detection catches manual changes
- Clean separation of concerns per workflow

### Negative

- Self-hosted runner is a security consideration (see ADR-0001)
- GitHub Issues for drift may create noise
- Pre-commit hooks require local setup

## Alternatives Considered

| Alternative            | Why Not Chosen                        |
| ---------------------- | ------------------------------------- |
| Atlantis               | Additional infrastructure to maintain |
| Spacelift/env0         | Cost, vendor lock-in                  |
| GitLab CI              | Would require repository migration    |
| Manual deployments     | Error-prone, not scalable             |
| Slack for drift alerts | Additional tool, cost, less traceable |
