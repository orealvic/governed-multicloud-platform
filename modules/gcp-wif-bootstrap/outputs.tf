output "project_number" {
  value = data.google_project.this.number
}

output "state_bucket" {
  value       = google_storage_bucket.tfstate.name
  description = "Bucket for every Terraform state file in this project."
}

output "workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full provider resource name for google-github-actions/auth."
}

output "deployer_service_account" {
  value       = google_service_account.deployer.email
  description = "Service account GitHub Actions impersonates."
}
