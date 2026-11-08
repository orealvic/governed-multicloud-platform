# gcp-wif-bootstrap

Layer 0 for one GCP project (one environment). Run once per project by an administrator; everything else then deploys through GitHub Actions without stored keys.

Creates:

- the listed Google APIs
- a versioned, destroy-protected Terraform state bucket
- a Workload Identity Federation pool and GitHub OIDC provider, restricted to one repository (and optionally its numeric id)
- a deployer service account, impersonable by:
  - any workflow in the repository, when `protected_environment` is empty (non-production)
  - only jobs in that GitHub environment, when set (production)
- an optional monthly budget with 50/90/100% actual and 100% forecast alerts

## First run on a new project

The state bucket must exist before `terraform init`, because the caller's backend lives in it. Create it with the CLI, then let the module adopt it:

```bash
gcloud services enable storage.googleapis.com --project "$PROJECT"
gcloud storage buckets create "gs://$PROJECT-tfstate" --project "$PROJECT" --location "$REGION" \
  --uniform-bucket-level-access --public-access-prevention
gcloud storage buckets update "gs://$PROJECT-tfstate" --versioning
```

```hcl
# in the calling root
import {
  to = module.bootstrap.google_storage_bucket.tfstate
  id = "my-project-tfstate"
}
```

## Inputs worth knowing

| Name | Notes |
|---|---|
| `github_repository` | `owner/repo`; tokens from any other repository are rejected |
| `github_repository_id` | Recommended. Numeric id, so a recreated repo with the same name is not trusted |
| `protected_environment` | Set to `prod` for production projects |
| `deployer_roles` | Least privilege: only what the project's Terraform manages. Grant `serviceAccountUser` on specific service accounts, not the project |
| `billing_account` | Empty skips the budget; needs Billing Account Administrator or Costs Manager |

## Outputs

`workload_identity_provider` and `deployer_service_account` go into the GitHub environment as `GCP_WIF_PROVIDER` and `GCP_DEPLOYER_SA`; `state_bucket` into `TF_BACKEND_CONFIG` as `bucket=<name>`.
