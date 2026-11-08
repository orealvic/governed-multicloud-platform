# 0003: Apply exactly the reviewed plan; gate production on a GitHub environment

**Status:** Accepted

## Context

A common pipeline runs `terraform apply -auto-approve` on merge. Nobody sees what will change in production before it happens, and the apply can differ from what was reviewed if anything changed in between.

GitHub environments can require reviewers, restrict which branches may deploy, and add a wait timer. Combined with OIDC trust bound to the environment (ADR 0001), the environment becomes the production change gate.

## Decision

- Every deployment is two jobs from the reusable `terraform.yml` workflow:
  1. **plan** saves the binary plan as a run artifact and writes a summary (counts and resource addresses only; the full plan can contain values and stays in the artifact).
  2. **apply** runs only when the plan has changes, downloads that artifact, and applies it unchanged.
- The production apply job runs in the `prod` environment, which:
  - allows deployments only from `main`
  - requires a named reviewer's approval
  - can add a wait timer
- The default branch is protected by a ruleset: pull requests only, required checks, no force-push, no deletion, linear history.
- Solo maintainers set required PR approvals to 0 (GitHub does not allow approving your own PR) and keep the human approval on the production environment, where approving your own deployment is allowed and recorded.

## Consequences

- Production changes are visible before they happen, approved by a person, and auditable in the environment's deployment history.
- No-op plans skip the approval prompt, so the gate only appears when something will change.
- A plan can go stale if production changes between plan and apply; Terraform then refuses to apply it and the run must be repeated. That failure is the desired behaviour.
- Planned next step: a separate read-only identity for plans, so pull requests can never write to any environment.
