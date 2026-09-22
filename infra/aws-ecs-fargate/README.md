# Deploy to AWS (ECS Fargate) — temporary/demo stack

Creates a **dedicated VPC** (2 public subnets, no NAT gateway), an ECR
repo, an ALB, and a 1-task ECS Fargate service running this app with its
default SQLite storage (no RDS). Built to be applied and destroyed
cleanly for a short-lived demo — not a long-term production setup. See
`docs/ARCHITECTURE.md` at the repo root for what a longer-lived version
would add (RDS, private subnets + NAT, autoscaling, HTTPS/ACM).

## Prerequisites

- AWS CLI configured with credentials that can create VPC/ECS/ECR/IAM/ALB
  resources (`aws sts get-caller-identity` should work).
- Terraform >= 1.5.
- Docker, for building/pushing the image.

## Why two applies

`container_image` has no default — Terraform can't know the ECR repo's
URL until the repo exists, and there's nothing to push an image to until
then. So: create the ECR repo first, push an image to it, *then* apply
everything else with that image URI.

## 1. Create the ECR repo

```bash
cd infra/aws-ecs-fargate
terraform init
terraform apply -target=aws_ecr_repository.app
```

Note the `ecr_repository_url` output — you'll need it in the next two
steps.

## 2. Build and push the image

From the repo root (not `infra/aws-ecs-fargate`):

```bash
aws ecr get-login-password --region <aws_region> \
  | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<aws_region>.amazonaws.com

docker build -t urlshort .
docker tag urlshort:latest <ecr_repository_url>:latest
docker push <ecr_repository_url>:latest
```

## 3. Apply the rest of the stack

```bash
cd infra/aws-ecs-fargate
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set container_image = "<ecr_repository_url>:latest"
terraform apply
```

Takes a few minutes (VPC + ALB provisioning, then the ECS service pulling
the image and passing its first health check). When it's done:

```bash
terraform output app_url
curl $(terraform output -raw app_url)/healthz
```

## Redeploying after a code change

```bash
docker build -t urlshort .
docker tag urlshort:latest <ecr_repository_url>:latest
docker push <ecr_repository_url>:latest
aws ecs update-service --cluster urlshort-cluster --service urlshort-service --force-new-deployment
```

(Terraform doesn't need to run again for an image-only change — the task
definition references the `:latest` tag, and `--force-new-deployment`
tells ECS to pull it fresh.)

## Tearing down

```bash
terraform destroy
```

`force_delete = true` on the ECR repo means this works in one pass even
with images still pushed — no manual "empty the repo first" step. If
`destroy` ever does hang, it's almost always the ALB's ENIs not having
finished detaching from the subnets yet; wait ~60s and re-run.

## What this does *not* include (by design, for a demo)

- No HTTPS (ALB is HTTP-only on port 80) — fine for a temporary demo URL,
  not for anything real. Adding it needs an ACM cert + a domain.
- No RDS — data doesn't survive a task restart. Intentional; see
  `docs/ARCHITECTURE.md`.
- No autoscaling — fixed at `desired_count = 1`.
- No remote Terraform state backend — state lives locally. Fine for one
  engineer running this alone; add an S3 backend before anyone else needs
  to touch this stack.
