# Bootstrap one GCP project for a GitHub repository.
# Values here are placeholders; real ones belong in the consuming (private) repo.

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # The state bucket is created with gcloud first, then adopted by the module
  # (see docs/adr/0002-remote-state.md).
  # backend "gcs" { prefix = "bootstrap" }
}

provider "google" {
  project               = "example-prod-123456"
  region                = "northamerica-northeast2"
  user_project_override = true
  billing_project       = "example-prod-123456"
}

module "bootstrap" {
  source = "../../modules/gcp-wif-bootstrap"

  project_id            = "example-prod-123456"
  region                = "northamerica-northeast2"
  github_repository     = "example-org/example-app"
  github_repository_id  = "123456789"
  protected_environment = "prod"

  apis = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "run.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]

  # Keep roles to what this project's Terraform manages. Grant
  # roles/iam.serviceAccountUser on the specific runtime service accounts, not
  # on the project, so the deployer cannot act as every identity.
  deployer_roles = [
    "roles/run.admin",
    "roles/storage.admin",
  ]

  labels = {
    env        = "prod"
    managed-by = "terraform"
  }
}

output "workload_identity_provider" {
  value = module.bootstrap.workload_identity_provider
}

output "deployer_service_account" {
  value = module.bootstrap.deployer_service_account
}
