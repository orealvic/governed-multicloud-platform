# Security policy

Report a vulnerability privately through GitHub: **Security → Report a vulnerability** on this repository. Please do not open a public issue.

## Design rules this repository follows

- No long-lived cloud credentials. Pipelines authenticate with GitHub's OIDC token through Workload Identity Federation (GCP) or federated credentials (Azure).
- This repository's own CI never authenticates to a cloud. Its workflows request no `id-token` permission.
- Third-party actions are pinned to full commit SHAs and updated by Dependabot.
- Workflow tokens default to read-only.
- Full Terraform plans are kept as access-controlled artifacts, not printed to logs.
