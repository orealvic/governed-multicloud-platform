output "environments" {
  value       = { for k, v in github_repository_environment.this : k => v.environment }
  description = "Environment names, keyed the same as the input."
}

output "ruleset_id" {
  value       = try(github_repository_ruleset.default_branch[0].ruleset_id, null)
  description = "Id of the default-branch ruleset, if enabled."
}
