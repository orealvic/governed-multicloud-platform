# 0002: All Terraform state is remote, versioned and destroy-protected, including bootstrap

**Status:** Accepted

## Context

Terraform state is the only record linking code to real resources. Lose it and Terraform believes nothing exists: the next apply tries to recreate everything, colliding with what is live.

The bootstrap layer creates the state bucket, so it is tempting to keep bootstrap's own state on the engineer's laptop. That is how this platform's first version worked, and a laptop re-image lost it. Recovery meant rebuilding state from the live resources with import blocks.

## Decision

- Every root, bootstrap included, uses a remote backend (GCS for GCP, a storage account container for Azure).
- Bootstrap breaks the chicken-and-egg problem by creating the state bucket once with the CLI, then adopting it into Terraform with an `import` block on the first apply. Bootstrap's state then lives in the bucket it manages, under its own prefix.
- State buckets have object versioning, public access prevention, uniform access, and `prevent_destroy`.
- One bucket per cloud project or subscription; one prefix per root. Environments never share a state file.

## Consequences

- A lost laptop or CI runner costs nothing.
- Versioning allows rolling back a corrupted state file.
- `prevent_destroy` means deleting a project's bootstrap requires a deliberate code change first.
- Engineers need read/write access to the state bucket, which is itself a sensitive asset: state can contain secrets. Access is limited to the deployer identity and administrators.
