# Module: ecs-fargate-app

Reusable building block: dedicated VPC (2 public subnets, no NAT), ECR
repo, ALB, and a single-task ECS Fargate service. No RDS, no HTTPS — see
"Not included" below.

This module holds *only* resources — no `provider` block (modules
shouldn't configure providers; that's the calling root module's job) and
no backend config. See `infra/environments/demo/` for a working example
of how to call it.

## Inputs

| Name | Description | Default |
|---|---|---|
| `aws_region` | Region (used for CloudWatch log group config) | — required |
| `project_name` | Prefix for all resource names/tags | `urlshort` |
| `vpc_cidr` | CIDR for the dedicated VPC | `10.20.0.0/16` |
| `public_subnet_cidrs` | 2 CIDRs, one per AZ | `["10.20.1.0/24", "10.20.2.0/24"]` |
| `container_port` | Port the app listens on | `8000` |
| `container_image` | Full ECR image URI:tag to run | — required, no default |
| `task_cpu` / `task_memory` | Fargate task sizing | `256` / `512` |
| `desired_count` | Number of tasks | `1` |
| `log_retention_days` | CloudWatch log retention | `3` |

## Outputs

`app_url`, `ecr_repository_url`, `ecs_cluster_name`, `ecs_service_name`, `vpc_id`

## Why no RDS / HTTPS / autoscaling

This module was built for a temporary demo deployment (see the root repo's
`docs/ARCHITECTURE.md`), not as a general-purpose "run anything on ECS"
module. If you're extending it for a real workload, the honest list of
what's missing:

- **Persistence**: the app falls back to SQLite inside the container if
  `URLSHORT_DATABASE_URL` isn't set. Add an RDS instance + private subnets
  + a NAT gateway (or VPC endpoints) before trusting this with real data.
- **HTTPS**: the ALB listener is HTTP-only on port 80. Add an ACM cert +
  a second listener on 443 + a domain.
- **Autoscaling**: `desired_count` is a fixed number, not hooked up to an
  Application Auto Scaling target.
