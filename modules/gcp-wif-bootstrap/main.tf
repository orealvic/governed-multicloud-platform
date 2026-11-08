# Layer 0 for one GCP project (one environment).
#
# Creates what every other Terraform root and pipeline depends on:
#   - the Google APIs the platform needs
#   - the versioned Terraform state bucket (protected from destroy)
#   - keyless GitHub Actions access via Workload Identity Federation
#   - the deployer service account GitHub impersonates
#   - an optional monthly budget with alert thresholds
#
# The caller owns the provider configuration and the backend.

data "google_project" "this" {
  project_id = var.project_id
}

locals {
  state_bucket_name = coalesce(var.state_bucket_name, "${var.project_id}-tfstate")

  # Built from the project number rather than the pool resource so the member
  # string is known at plan time (import ids in callers depend on it).
  pool_name = "projects/${data.google_project.this.number}/locations/global/workloadIdentityPools/${var.pool_id}"

  # With a protected environment, only jobs running in that GitHub environment
  # can impersonate the deployer. Otherwise any workflow in the repository can.
  wif_member = var.protected_environment != "" ? (
    "principalSet://iam.googleapis.com/${local.pool_name}/attribute.environment/${var.protected_environment}"
    ) : (
    "principalSet://iam.googleapis.com/${local.pool_name}/attribute.repository/${var.github_repository}"
  )
}

resource "google_project_service" "apis" {
  for_each           = toset(var.apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ── Terraform remote state ───────────────────────────────────────────────────
resource "google_storage_bucket" "tfstate" {
  project                     = var.project_id
  name                        = local.state_bucket_name
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = var.state_versions_to_keep
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # This bucket holds every state file for the project, often including the
  # state of the root that calls this module.
  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.apis]
}

# ── Keyless GitHub Actions access ────────────────────────────────────────────
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.pool_id
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.provider_id
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.ref"         = "assertion.ref"
    "attribute.environment" = "assertion.environment"
  }

  # Hard stop: tokens from any other repository are rejected outright. With the
  # numeric repository id as well, a deleted-and-recreated repository with the
  # same name cannot inherit the trust.
  attribute_condition = join(" && ", compact([
    "assertion.repository == \"${var.github_repository}\"",
    var.github_repository_id == "" ? "" : "assertion.repository_id == \"${var.github_repository_id}\"",
  ]))

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = var.deployer_account_id
  display_name = var.deployer_display_name
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(var.deployer_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = local.wif_member

  depends_on = [google_iam_workload_identity_pool.github]
}

# ── Budget (needs Billing Account Administrator or Costs Manager) ────────────
resource "google_billing_budget" "monthly" {
  count           = var.billing_account == "" ? 0 : 1
  billing_account = var.billing_account
  display_name    = var.budget_display_name

  budget_filter {
    projects = ["projects/${data.google_project.this.number}"]
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency
      units         = tostring(var.budget_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  depends_on = [google_project_service.apis]
}
