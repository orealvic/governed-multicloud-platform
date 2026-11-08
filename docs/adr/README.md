# Architecture decision records

Short records of significant decisions: the context, the choice, and its consequences. New decisions get the next number; superseded ones stay, marked as such.

| # | Decision | Status |
|---|---|---|
| [0001](0001-keyless-oidc.md) | Pipelines authenticate to clouds with OIDC, never stored keys | Accepted |
| [0002](0002-remote-state.md) | All Terraform state is remote, versioned and destroy-protected, including bootstrap | Accepted |
| [0003](0003-plan-apply-gates.md) | Apply exactly the reviewed plan; gate production on a GitHub environment | Accepted |
