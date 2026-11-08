# Repository delivery governance as code:
#   - deployment environments, their variables and protection rules
#   - repository-level Actions variables
#   - an optional ruleset on the default branch
#
# Environment protection (reviewers, branch policies) and rulesets on a
# private repository need GitHub Pro, Team or Enterprise.

locals {
  reviewer_usernames = toset(flatten([for env in values(var.environments) : env.reviewers]))

  env_vars = merge([
    for env, cfg in var.environments : {
      for name, value in cfg.variables : "${env}/${name}" => { env = env, name = name, value = value }
    }
  ]...)

  branch_policies = merge([
    for env, cfg in var.environments : {
      for pattern in cfg.branches : "${env}/${pattern}" => { env = env, pattern = pattern }
    }
  ]...)
}

data "github_user" "reviewer" {
  for_each = local.reviewer_usernames
  username = each.value
}

resource "github_repository_environment" "this" {
  for_each            = var.environments
  repository          = var.repository
  environment         = each.key
  wait_timer          = each.value.wait_timer
  can_admins_bypass   = each.value.admins_can_bypass
  prevent_self_review = each.value.prevent_self_review

  dynamic "reviewers" {
    for_each = length(each.value.reviewers) > 0 ? [1] : []
    content {
      users = [for u in each.value.reviewers : data.github_user.reviewer[u].id]
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = length(each.value.branches) > 0 ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "this" {
  for_each       = local.branch_policies
  repository     = var.repository
  environment    = github_repository_environment.this[each.value.env].environment
  branch_pattern = each.value.pattern
}

resource "github_actions_environment_variable" "this" {
  for_each      = local.env_vars
  repository    = var.repository
  environment   = github_repository_environment.this[each.value.env].environment
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_variable" "this" {
  for_each      = var.repository_variables
  repository    = var.repository
  variable_name = each.key
  value         = each.value
}

# ── Default-branch ruleset ───────────────────────────────────────────────────
resource "github_repository_ruleset" "default_branch" {
  count       = var.default_branch_ruleset.enabled ? 1 : 0
  name        = "default-branch"
  repository  = var.repository
  target      = "branch"
  enforcement = var.default_branch_ruleset.enforcement

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Repository admins can bypass, and every bypass is recorded in the
  # ruleset's insights. Remove this block to make the rules absolute.
  dynamic "bypass_actors" {
    for_each = var.default_branch_ruleset.admin_bypass ? [1] : []
    content {
      actor_id    = 5 # built-in "Repository admin" role
      actor_type  = "RepositoryRole"
      bypass_mode = "pull_request"
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      required_approving_review_count   = var.default_branch_ruleset.required_approvals
      require_code_owner_review         = var.default_branch_ruleset.require_code_owner_review
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = false
      required_review_thread_resolution = true
    }

    dynamic "required_status_checks" {
      for_each = length(var.default_branch_ruleset.required_checks) > 0 ? [1] : []
      content {
        strict_required_status_checks_policy = true

        dynamic "required_check" {
          for_each = var.default_branch_ruleset.required_checks
          content {
            context = required_check.value
          }
        }
      }
    }
  }
}
