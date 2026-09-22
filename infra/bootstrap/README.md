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
  -var="github_repo=urlshort" \
  -var="aws_region=<the region you actually want everything in, e.g. ap-southeast-1>"
```

**Always pass `aws_region` explicitly.** Leaving it out silently falls
back to the default in `variables.tf` — which may not be the region you
think you're using. This exact mistake happened once already: the state
bucket got created in one region while `AWS_REGION` in GitHub was set to
a different one, and `terraform init` failed with
`IllegalLocationConstraintException` because the backend config's region
didn't match the bucket's actual home region. Whatever region you pass
here is what `environments/demo` needs to match later, in its own
`aws_region` var and in the `AWS_REGION` GitHub repo variable below.

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

## Known gotcha: first-ever ECS use in an account

If this is the very first time ECS has been used in this AWS account,
`deploy.yml`'s `terraform apply` may fail creating the ECS service with
`Unable to assume the service linked role`. This IAM role
(`AWSServiceRoleForECS`) is normally auto-created the first time you use
ECS via the console; via pure API/Terraform it needs
`iam:CreateServiceLinkedRole`, which this bootstrap's policy already
grants — so this should now self-heal on its own. If it doesn't (e.g. an
older/cached policy), the one-time manual fix is:

```bash
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
```

(If it says the role already exists, that's fine — it means this isn't
your problem.)

## State for this bootstrap stack itself

This stack's own state is local (`terraform.tfstate` in this folder,
gitignored). That's intentional — it creates the remote backend, so it
can't use it. Keep this state file somewhere safe (or re-run `apply`
later; the S3 bucket/DynamoDB table/IAM role are cheap to describe again
if you ever lose it — just don't `terraform destroy` this stack while
`environments/demo` still depends on it).
