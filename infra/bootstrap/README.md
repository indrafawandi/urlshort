# Bootstrap (one-time, manual — run this once from your own machine)

This is the one part of the whole setup that genuinely can't be automated
away: GitHub Actions needs an AWS IAM role to assume before it can do
anything, and that role has to be created by *someone who already has AWS
access*. Everything downstream of this (the actual app deployment) is
fully automated by `.github/workflows/deploy.yml` — this is the only
manual step in the whole pipeline.

Creates:
- An S3 bucket + DynamoDB table for Terraform remote state (so CI runs
  don't lose state between runs — a GitHub Actions runner's filesystem is
  thrown away after every job).
- A GitHub OIDC provider + IAM role, scoped to *this* repo, that
  `deploy.yml`/`destroy.yml` assume via short-lived credentials (no AWS
  access keys stored as GitHub secrets).

## Run it

```bash
cd infra/bootstrap
terraform init
terraform apply \
  -var="state_bucket_name=<something-globally-unique, e.g. urlshort-tfstate-fawandi>" \
  -var="github_org=<your GitHub username or org>" \
  -var="github_repo=urlshort"
```

## Then, wire the outputs into GitHub

Take the three outputs and add them as **repository variables** (Settings
→ Secrets and variables → Actions → Variables — these aren't secrets,
they're just config, hence variables not secrets):

| Terraform output | GitHub repo variable |
|---|---|
| `github_actions_role_arn` | `AWS_OIDC_ROLE_ARN` |
| `state_bucket_name` | `TF_STATE_BUCKET` |
| `lock_table_name` | `TF_LOCK_TABLE` |

Also add two more repo variables by hand (not Terraform outputs, just your
choices):

| Variable | Example |
|---|---|
| `AWS_REGION` | `ap-southeast-1` |
| `PROJECT_NAME` | `urlshort` |

Once those five variables are set, push to `main` (or run the `Deploy`
workflow manually) and the rest happens without touching AWS by hand
again.

## State for this bootstrap stack itself

This stack's own state is local (`terraform.tfstate` in this folder,
gitignored). That's intentional — it creates the remote backend, so it
can't use it. Keep this state file somewhere safe (or re-run `apply`
later; the S3 bucket/DynamoDB table/IAM role are cheap to describe again
if you ever lose it — just don't `terraform destroy` this stack while
`environments/demo` still depends on it).
