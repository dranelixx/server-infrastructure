<!-- LAST EDITED: 2026-01-27 -->

# ADR-0001: Self-hosted GitHub Runner

## Status

Accepted

## Context

GitHub Actions workflows need to execute Terraform and Ansible against Proxmox hosts in a private
colocation network. GitHub-hosted runners run in GitHub's cloud infrastructure and have no network
access to private infrastructure.

## Decision

Deploy a self-hosted GitHub Actions runner (`github-runner-prod-cz-01`) as an LXC container within
the private network. The runner is provisioned via Ansible (`ansible/roles/github-runner/`) for
reproducibility and documentation.

### Why Ansible instead of Docker?

For a single persistent runner, Ansible is more pragmatic:

- Runner maintains state between jobs (build caches, pre-installed tools)
- Direct SSH access for debugging
- Setup is already documented and reproducible via Ansible role
- Docker-based ephemeral runners add complexity without benefit for current scale

## Consequences

### Positive

- CI/CD pipelines can reach private Proxmox APIs
- Full control over runner environment and installed tools
- No dependency on GitHub's runner availability

### Negative

- **Security Risk**: Code executed by workflows runs on a machine with direct API access
- A compromised PR or malicious dependency could access Proxmox API
- Runner requires maintenance and updates

### Mitigations (TODO)

- After VLAN migration: Isolate runner in restricted network segment
- Create dedicated Proxmox API token with minimal permissions
- Restrict workflow execution to protected branches with PR approval
- Evaluate migration to Docker-based ephemeral runner for clean state per job

## Alternatives Considered

| Alternative                       | Why Not Chosen                                         |
| --------------------------------- | ------------------------------------------------------ |
| GitHub-hosted runners + VPN       | Complexity of maintaining VPN tunnel, latency          |
| GitHub-hosted runners + Tailscale | Additional dependency, still requires agent in network |
| No CI/CD automation               | Manual deployments are error-prone and not scalable    |
