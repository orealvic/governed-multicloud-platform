# Governance for one repository: dev deploys from any branch, prod only from
# main after a named reviewer approves, and main only changes through PRs.

terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.2"
    }
  }
}

provider "github" {
  owner = "example-org"
}

module "governance" {
  source = "../../modules/github-environments"

  repository = "example-app"

  repository_variables = {
    GCP_REGION = "northamerica-northeast2"
  }

  environments = {
    dev = {
      variables = { GCP_PROJECT_ID = "example-dev-123456" }
    }
    prod = {
      variables  = { GCP_PROJECT_ID = "example-prod-123456" }
      reviewers  = ["example-maintainer"]
      branches   = ["main"]
      wait_timer = 5
    }
  }

  default_branch_ruleset = {
    enabled         = true
    required_checks = ["fmt + validate", "tests"]
  }
}
