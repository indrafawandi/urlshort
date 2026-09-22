# infra/

```
infra/
  modules/ecs-fargate-app/   reusable Terraform module (VPC, ALB, ECS, ECR, IAM)
  environments/demo/         root config that calls the module for this one demo env
  bootstrap/                 one-time manual setup: state backend + GitHub OIDC role
```

## Deploying (fully automated after bootstrap)

1. **One-time, manual**: follow `bootstrap/README.md`. This is the only
   step that can't run from CI — it's what *creates* CI's AWS access.
2. **Every deploy after that**: GitHub Actions → `Deploy to AWS (ECS
   Fargate)` → Run workflow → type `deploy` to confirm. That single
   trigger does everything: creates the ECR repo (if needed), builds and
   pushes the image tagged with the commit SHA, and applies the full
   VPC/ALB/ECS stack via Terraform. Takes a few minutes; the app URL shows
   up in the workflow's job summary.
3. **Tearing down**: GitHub Actions → `Destroy AWS stack` → Run workflow →
   type `destroy` to confirm.

See `environments/demo/README.md`... actually there isn't one — the
`.github/workflows/deploy.yml` and `destroy.yml` files themselves are the
source of truth for the exact commands, since that's what actually runs.
If you want to run Terraform locally instead of via CI (e.g. to debug),
use the same `-backend-config` flags and `-var` flags those workflows use,
with your own AWS credentials (`aws configure` or `aws sso login`) instead
of OIDC.

## Why a module

`modules/ecs-fargate-app` has no provider config and no backend — it's
just resources, parameterized. `environments/demo` is the only thing that
configures a provider/backend and actually calls the module. If this ever
needs a second environment (e.g. `environments/staging`), that's a new
folder next to `demo/` that calls the same module with different
`terraform.tfvars` — no duplicated resource definitions.

## Why CI needs its own AWS role (bootstrap)

GitHub Actions can't have AWS access it wasn't explicitly given. The
bootstrap stack creates a narrowly-scoped IAM role that only this repo's
workflows can assume (via OIDC — no static AWS keys sitting in GitHub
secrets), plus the S3/DynamoDB backend Terraform needs so state survives
between CI runs (a GitHub Actions runner's disk is wiped after every job —
local state, like the earlier single-folder version of this stack used,
would mean every CI run starts from zero and tries to recreate everything).
