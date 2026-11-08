variable "repository" {
  type        = string
  description = "Repository name (without the owner)."
}

variable "environments" {
  description = <<-EOT
    Deployment environments keyed by name.
      variables           Actions variables scoped to the environment
      reviewers           GitHub usernames who must approve deployments
      branches            branch name patterns allowed to deploy (empty = any branch)
      wait_timer          minutes to wait before a deployment proceeds
      admins_can_bypass   whether repository admins can skip protection rules
      prevent_self_review whether the person who triggered a run is barred from approving it
  EOT
  type = map(object({
    variables           = optional(map(string), {})
    reviewers           = optional(list(string), [])
    branches            = optional(list(string), [])
    wait_timer          = optional(number, 0)
    admins_can_bypass   = optional(bool, true)
    prevent_self_review = optional(bool, false)
  }))
}

variable "repository_variables" {
  type        = map(string)
  description = "Repository-level Actions variables."
  default     = {}
}

variable "default_branch_ruleset" {
  description = <<-EOT
    Ruleset on the default branch: no deletion, no force-push, linear history,
    changes only through pull requests, optional required status checks.
    required_approvals = 0 suits a solo maintainer (GitHub does not let you
    approve your own pull request); put the human approval on the production
    environment instead.
  EOT
  type = object({
    enabled                   = optional(bool, false)
    enforcement               = optional(string, "active")
    required_approvals        = optional(number, 0)
    require_code_owner_review = optional(bool, false)
    required_checks           = optional(list(string), [])
    admin_bypass              = optional(bool, true)
  })
  default = {}

  validation {
    condition     = contains(["active", "evaluate", "disabled"], var.default_branch_ruleset.enforcement)
    error_message = "enforcement must be active, evaluate or disabled."
  }
}
