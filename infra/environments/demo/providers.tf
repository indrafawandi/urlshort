terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial config: bucket/region/dynamodb_table are supplied at `terraform
  # init` time via -backend-config flags (see README.md and
  # .github/workflows/deploy.yml). This keeps account-specific values
  # (the state bucket name is globally unique, i.e. account-specific) out
  # of version control.
  #
  # Remote state is not optional here, unlike the single-file demo stack
  # this replaced: once Terraform runs from a GitHub Actions runner, local
  # state would be thrown away after every run. This bucket/table is
  # created once by infra/bootstrap/ — see its README.md.
  backend "s3" {
    key = "urlshort/demo/terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Purpose   = "demo-temporary"
    }
  }
}
