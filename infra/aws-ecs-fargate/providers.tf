terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # No remote backend configured on purpose: this stack is meant to be
  # applied and destroyed for short-lived demos, run from a single
  # engineer's machine. If this becomes a long-lived environment, add an S3
  # backend + DynamoDB lock table before anyone else touches it.
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
