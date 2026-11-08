variable "project_id" {
  type        = string
  description = "GCP project id for this environment."
}

variable "region" {
  type        = string
  description = "Region for the state bucket."
}

variable "github_repository" {
  type        = string
  description = "owner/repo allowed to authenticate through Workload Identity Federation."

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo form."
  }
}

variable "github_repository_id" {
  type        = string
  description = "Numeric id of the repository (gh api repos/OWNER/REPO --jq .id). Recommended: also binds trust to the id, so a recreated repository with the same name is not trusted. Empty checks the name only."
  default     = ""
}

variable "protected_environment" {
  type        = string
  description = "GitHub environment whose jobs may impersonate the deployer (e.g. \"prod\"). Empty trusts every workflow in the repository, which is only appropriate for non-production projects."
  default     = ""
}

variable "apis" {
  type        = list(string)
  description = "Google APIs to enable. Include storage, iam, iamcredentials, sts and cloudresourcemanager at minimum."
  default = [
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]
}

variable "deployer_roles" {
  type        = list(string)
  description = "Project roles granted to the deployer service account. Keep this to what the platform's Terraform actually manages."
}

variable "deployer_account_id" {
  type    = string
  default = "gh-deployer"
}

variable "deployer_display_name" {
  type    = string
  default = "GitHub Actions deployer"
}

variable "pool_id" {
  type    = string
  default = "github"
}

variable "provider_id" {
  type    = string
  default = "github-oidc"
}

variable "state_bucket_name" {
  type        = string
  description = "State bucket name. Empty uses <project_id>-tfstate."
  default     = ""
}

variable "state_versions_to_keep" {
  type        = number
  description = "Archived state versions kept per object."
  default     = 20
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "billing_account" {
  type        = string
  description = "Billing account id (XXXXXX-XXXXXX-XXXXXX). Empty skips the budget."
  default     = ""
}

variable "budget_display_name" {
  type    = string
  default = "monthly-budget"
}

variable "budget_amount" {
  type    = number
  default = 100
}

variable "budget_currency" {
  type        = string
  description = "Must match the billing account's currency."
  default     = "CAD"
}

variable "budget_thresholds" {
  type        = list(number)
  description = "Actual-spend alert thresholds as fractions of the budget. A 100% forecast alert is always added."
  default     = [0.5, 0.9, 1.0]
}
