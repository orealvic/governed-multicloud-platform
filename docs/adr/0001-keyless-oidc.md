# 0001: Pipelines authenticate to clouds with OIDC, never stored keys

**Status:** Accepted

## Context

CI/CD needs to change cloud resources. The traditional approach is a service-account key (GCP) or client secret (Azure) stored as a CI secret. Those credentials are long-lived, work from anywhere, are rarely rotated, and are the most common way pipelines get breached.

GitHub Actions can issue a short-lived OIDC token per job. The token is signed by GitHub and carries claims about the job: repository, branch (`ref`), and the deployment `environment` it runs in.

## Decision

- **GCP:** Workload Identity Federation. A pool and provider trust `token.actions.githubusercontent.com`. The provider's attribute condition accepts tokens from **one repository only**. The deployer service account grants `roles/iam.workloadIdentityUser` to:
  - non-production: any job in the repository
  - production: only jobs whose token says `environment=prod`
- **Azure:** an Entra app registration (or user-assigned managed identity) with a federated credential per environment, subject `repo:<owner>/<repo>:environment:<env>`.
- No cloud credential is ever stored in GitHub.

## Consequences

- Nothing to leak or rotate. A token is useful for minutes and only from a job matching the trust conditions.
- Production trust depends on GitHub environment protection. An unprotected `prod` environment lets any branch mint a `prod` token, so the environment **must** be restricted to `main` with a required reviewer (ADR 0003). On a private repository this needs a paid GitHub plan.
- Bootstrapping the trust itself still needs a human with cloud admin rights, once per project (ADR 0002).
