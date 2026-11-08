# github-environments

Repository delivery governance as code, so changes to the rules are themselves reviewed in a pull request.

- **Environments** with their Actions variables, required reviewers, allowed branches and wait timer.
- **Repository variables.**
- **Default-branch ruleset** (optional): no deletion, no force-push, linear history, pull requests only, required status checks.

Environment protection rules and rulesets on a **private** repository need GitHub Pro, Team or Enterprise.

## The production gate

```hcl
environments = {
  prod = {
    reviewers  = ["your-username"]
    branches   = ["main"]
    wait_timer = 5
  }
}
```

With the GCP or Azure trust bound to `environment=prod` (see `gcp-wif-bootstrap`), this environment is the only way to get production credentials, and it only opens for `main` after approval.

## Solo maintainers

GitHub does not let you approve your own pull request, so keep `required_approvals = 0` on the ruleset and enforce quality with `required_checks`. The human approval lives on the production environment, where you can approve your own deployment and it is recorded.

The status check names must match the job names exactly as GitHub shows them on a pull request.
