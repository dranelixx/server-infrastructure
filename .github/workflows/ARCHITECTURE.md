<!-- LAST EDITED: 2026-02-13 -->

# Terraform Workflows - Architecture

## Workflow Overview

```mermaid
graph TB
    subgraph "Drift Detection (Daily 06:00 UTC)"
        A[terraform-drift.yml] --> B{Drift detected?}
        B -->|Yes| C[Create GitHub Issue]
        B -->|No| D[Close issue if open]
        C --> E[Upload Plan Artifacts]
        D --> E
    end

    subgraph "Pull Request Workflow"
        F[Developer creates PR] --> G[terraform-plan.yml]
        G --> H[Terraform Init + Plan]
        H --> I[Plan as PR comment]
        I --> J{Review OK?}
        J -->|Yes| K[PR Merge]
        J -->|No| L[Make changes]
        L --> F
    end

    subgraph "Apply Workflow (with Approval)"
        K --> M[terraform-apply.yml]
        M --> N{Environment Detection}
        N -->|current-state| O[Plan current-state]
        N -->|target-state| P[Plan target-state]
        O --> Q{Manual Approval}
        P --> Q
        Q -->|Approved| R[Terraform Apply]
        R --> S{Apply successful?}
        S -->|Yes| T[Upload Logs]
        S -->|No| U[Create Failure Issue]
        U --> T
    end

    style C fill:#ff6b6b
    style D fill:#51cf66
    style K fill:#4dabf7
    style Q fill:#ffd43b
    style U fill:#ff6b6b
```

## Workflow Details

### 1. Drift Detection Workflow

```mermaid
sequenceDiagram
    participant Cron
    participant Workflow
    participant Terraform
    participant Proxmox
    participant GitHub

    Cron->>Workflow: Trigger (06:00 UTC)
    Workflow->>Terraform: terraform init
    Workflow->>Terraform: terraform plan -detailed-exitcode
    Terraform->>Proxmox: API: Get current state
    Proxmox-->>Terraform: Current infrastructure
    Terraform-->>Workflow: Exit code (0, 1, or 2)

    alt Exit code = 2 (Drift)
        Workflow->>GitHub: Create/Update Issue
        Workflow->>GitHub: Upload Plan Artifact
    else Exit code = 0 (No drift)
        Workflow->>GitHub: Close existing Issues
    else Exit code = 1 (Error)
        Workflow->>GitHub: Workflow Failed
    end
```

### 2. Pull Request Workflow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git
    participant GHA as GitHub Actions
    participant TF as Terraform
    participant PVE as Proxmox

    Dev->>Git: git push origin feature-branch
    Git->>GHA: Trigger PR Workflow
    GHA->>TF: terraform fmt -check
    GHA->>TF: terraform init
    GHA->>TF: terraform validate
    GHA->>TF: terraform plan
    TF->>PVE: API: Query resources
    PVE-->>TF: Resource state
    TF-->>GHA: Plan output
    GHA->>Git: Post plan as PR comment
    Dev->>Git: Review plan
    Dev->>Git: Approve + Merge PR
```

### 3. Apply Workflow

```mermaid
sequenceDiagram
    participant Git
    participant GHA as GitHub Actions
    participant Approver
    participant TF as Terraform
    participant PVE as Proxmox
    participant State as TF State

    Git->>GHA: Push to main
    GHA->>GHA: Detect changed environments
    GHA->>TF: terraform init
    GHA->>TF: terraform plan
    TF->>PVE: API: Get current state
    PVE-->>TF: Infrastructure state
    TF-->>GHA: Plan with changes

    alt Changes detected
        GHA->>Approver: Request manual approval
        Approver-->>GHA: Approve deployment
        GHA->>TF: terraform apply -auto-approve
        TF->>PVE: API: Create/Update resources
        PVE-->>TF: Success/Failure
        TF->>State: Update state file
        TF-->>GHA: Apply result

        alt Apply failed
            GHA->>Git: Create failure issue
            GHA->>Git: Upload logs (90d retention)
        else Apply successful
            GHA->>Git: Upload logs (90d retention)
            GHA->>Git: Post summary
        end
    else No changes
        GHA->>Git: Skip apply, no changes
    end
```

## Concurrency Control

```mermaid
graph LR
    subgraph "terraform-drift.yml"
        A1[Run 1] -.block.-> A2[Run 2 - Queued]
        A2 -.block.-> A3[Run 3 - Queued]
    end

    subgraph "terraform-plan.yml"
        B1[PR #1 - Run 1] -.cancel.-> B2[PR #1 - Run 2]
        C1[PR #2 - Run 1] -.independent.-> B1
    end

    subgraph "terraform-apply.yml"
        D1[Apply Run 1] -.block.-> D2[Apply Run 2 - Queued]
    end

    style A2 fill:#ffd43b
    style A3 fill:#ffd43b
    style D2 fill:#ffd43b
    style B2 fill:#ff6b6b
```

### Concurrency Groups

| Workflow | Group | Strategy | Reason |
|----------|-------|----------|--------|
| `terraform-drift.yml` | `terraform-drift` | Queue | Prevents state locks |
| `terraform-plan.yml` | `terraform-plan-${{ pr }}` | Cancel in progress | Saves resources on quick updates |
| `terraform-apply.yml` | `terraform-apply` | Queue | Critical - no race conditions |

## Shared Setup (Composite Action)

All Terraform jobs use the shared Composite Action `.github/actions/terraform-setup/` which handles:

1. **Import Secrets from Vault** — `hashicorp/vault-action@v3` (environment-specific secrets passed as input)
2. **Configure AWS Credentials** — `aws-actions/configure-aws-credentials@v4` (OIDC federation)
3. **Setup Terraform** — `hashicorp/setup-terraform@v3` (version centralized in action default)
4. **Terraform fmt** — optional (`run-fmt` input, default: `true`)
5. **Terraform init** — always runs
6. **Terraform validate** — optional (`run-validate` input, default: `true`)

**Note:** `actions/checkout@v4` must run **before** the composite action call (GitHub needs the
repo checked out to find local actions).

Apply workflows set `run-fmt: 'false'`, `run-validate: 'false'`, and `terraform-wrapper: 'false'`.

## Security Model

```mermaid
graph TB
    subgraph "GitHub Secrets (Bootstrap)"
        GS1[VAULT_ADDR]
        GS2[VAULT_ROLE_ID]
        GS3[VAULT_SECRET_ID]
    end

    subgraph "HashiCorp Vault (Primary Secrets)"
        V1[Proxmox API Credentials]
        V2[SSH Public Keys]
        V3[AWS OIDC Role ARN]
    end

    subgraph "AWS IAM (OIDC Federation)"
        OIDC[GitHub OIDC Provider]
        STS[Temporary STS Credentials]
    end

    subgraph "GitHub Runner (Self-hosted)"
        R1[Terraform CLI]
        R2[Environment Variables]
    end

    subgraph "External Services"
        P1[Proxmox API :8006]
        S3[S3 State Backend]
    end

    subgraph "Protection Layers"
        L1[Branch Protection]
        L2[Environment Protection]
        L3[Required Reviewers]
        L4[CODEOWNERS]
    end

    GS1 --> V1
    GS2 --> V1
    GS3 --> V1
    V1 --> R2
    V2 --> R2
    V3 -->|Role ARN| OIDC
    OIDC -->|OIDC Token| STS
    STS --> R2
    R2 --> R1
    R1 -->|HTTPS + TLS| P1
    R1 -->|HTTPS + STS| S3

    L1 -.enforces.-> L2
    L2 -.enforces.-> L3
    L3 -.enforces.-> L4

    style GS1 fill:#868e96
    style GS2 fill:#868e96
    style GS3 fill:#868e96
    style V1 fill:#be4bdb
    style V2 fill:#be4bdb
    style V3 fill:#be4bdb
    style OIDC fill:#4dabf7
    style STS fill:#4dabf7
    style L1 fill:#51cf66
    style L2 fill:#51cf66
    style L3 fill:#51cf66
    style L4 fill:#51cf66
```

## Issue Management

```mermaid
stateDiagram-v2
    [*] --> NoDrift: Initial State
    NoDrift --> DriftDetected: Drift found
    DriftDetected --> IssueCreated: Create GitHub Issue
    IssueCreated --> IssueUpdated: Daily update (drift persists)
    IssueUpdated --> IssueUpdated: Drift still present
    IssueUpdated --> IssueClosed: Drift resolved
    IssueClosed --> NoDrift: Back to normal
    NoDrift --> NoDrift: Daily check (no drift)

    DriftDetected --> ApplyFailed: Manual fix attempt failed
    ApplyFailed --> FailureIssue: Create urgent issue
    FailureIssue --> ManualIntervention: Team action required
    ManualIntervention --> IssueClosed: Problem resolved
```

### Issue Labels

```mermaid
graph LR
    subgraph "Drift Detection Issues"
        D1[drift-detection]
        D2[terraform]
        D3[current-state / target-state]
    end

    subgraph "Apply Failure Issues"
        A1[apply-failure]
        A2[terraform]
        A3[urgent]
        A4[current-state / target-state]
    end

    style A1 fill:#ff6b6b
    style A3 fill:#ff6b6b
    style D1 fill:#ffd43b
```

## Environment Flow

```mermaid
graph LR
    subgraph "Git Repository"
        DEV[feature/* branches]
        MAIN[main branch]
    end

    subgraph "Terraform Environments"
        CURR[current-state/]
        TARG[target-state/]
    end

    subgraph "Proxmox Cluster"
        PVE[pve-prod-cz-loki]
    end

    subgraph "Workflows"
        PLAN[Plan Workflow]
        APPLY[Apply Workflow]
        DRIFT[Drift Workflow]
    end

    DEV -->|Pull Request| PLAN
    PLAN -.validates.-> CURR
    PLAN -.validates.-> TARG

    MAIN -->|Merge| APPLY
    APPLY -->|modifies| PVE

    CURR -.maps to.-> PVE
    TARG -.maps to.-> PVE

    DRIFT -->|daily check| CURR
    DRIFT -->|daily check| TARG
    DRIFT -.compares.-> PVE

    style MAIN fill:#4dabf7
    style DEV fill:#51cf66
    style PVE fill:#ff6b6b
```

## Artifact Retention

```mermaid
gantt
    title Artifact Lifecycle
    dateFormat X
    axisFormat %d days

    section Drift Detection
    Plan Artifacts (30d) :30, 30

    section PR Plans
    Plan Artifacts (30d) :30, 30

    section Apply Logs
    Apply Logs (90d) :90, 90
    Plan Outputs (90d) :90, 90
```

## Best Practices Implementation

```mermaid
mindmap
  root((Terraform<br/>Workflows))
    Security
      API Token Rotation
      Secret Management
      TLS Verification
      Least Privilege
    Reliability
      Concurrency Control
      State Locking
      Error Handling
      Retry Logic
    Visibility
      PR Comments
      Issue Creation
      Artifacts Upload
      Summary Reports
    Compliance
      Manual Approvals
      Audit Logs
      Change Tracking
      Review Process
```

## Workflow Triggers Matrix

| Event | Drift | Plan | Apply |
|-------|-------|------|-------|
| Schedule (Cron) | ✅ 06:00 UTC | ❌ | ❌ |
| Push to main | ⚠️ Optional | ❌ | ✅ |
| Pull Request | ❌ | ✅ | ❌ |
| workflow_dispatch | ✅ | ❌ | ✅ |

## Permissions Model

```yaml
# terraform-drift.yml
permissions:
  contents: read      # Checkout code
  issues: write       # Create/update drift issues
  id-token: write     # AWS OIDC federation

# terraform-plan.yml
permissions:
  contents: read      # Checkout code
  pull-requests: write # Post plan comments
  issues: write       # Create issues on errors
  id-token: write     # AWS OIDC federation

# terraform-apply.yml
permissions:
  contents: read      # Checkout code
  issues: write       # Create failure issues
  id-token: write     # AWS OIDC federation
```

## Error Handling Strategy

```mermaid
graph TB
    START[Workflow Start] --> INIT{Init Success?}
    INIT -->|No| ERR1[Post Error + Exit]
    INIT -->|Yes| VAL{Validate Success?}
    VAL -->|No| ERR2[Post Error + Exit]
    VAL -->|Yes| PLAN{Plan Success?}

    PLAN -->|No| ERR3[Post Error + Exit]
    PLAN -->|Yes| CHECK{Changes?}

    CHECK -->|No| SKIP[Skip Apply]
    CHECK -->|Yes| APPLY{Apply Success?}

    APPLY -->|No| ISSUE[Create Failure Issue]
    APPLY -->|Yes| SUCCESS[Upload Logs]

    ISSUE --> UPLOAD[Upload Logs]
    SUCCESS --> END[Workflow Complete]
    UPLOAD --> END
    SKIP --> END

    style ERR1 fill:#ff6b6b
    style ERR2 fill:#ff6b6b
    style ERR3 fill:#ff6b6b
    style ISSUE fill:#ff6b6b
    style SUCCESS fill:#51cf66
```

## Resources

- [Terraform CLI Docs](https://www.terraform.io/cli)
- [bpg/proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
- [GitHub Actions Contexts](https://docs.github.com/en/actions/learn-github-actions/contexts)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
