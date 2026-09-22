terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Deliberately local state for the bootstrap stack itself — it's what
  # *creates* the remote backend that everything else uses, so it can't
  # depend on that backend existing yet. This is the one piece of state
  # you keep on your own machine (or hand to whoever maintains this next).
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------
# Remote state backend for infra/environments/*
# ---------------------------------------------------------------------

resource "aws_s3_bucket" "tf_state" {
  # Bucket names are globally unique across all of AWS — the default
  # below almost certainly needs to change. See variables.tf.
  bucket = var.state_bucket_name
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ---------------------------------------------------------------------
# GitHub Actions OIDC — lets the workflow assume an AWS role with
# short-lived, auto-rotating credentials. No long-lived AWS access keys
# stored as GitHub secrets.
# ---------------------------------------------------------------------

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "github_oidc_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Scopes the role to THIS repo only, and (by default) any branch/PR
    # in it. Tighten the ref to e.g. "repo:<org>/<repo>:ref:refs/heads/main"
    # if you only want main-branch pushes to be able to assume this role.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project_name}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_assume.json
}

# Scoped to what deploy.yml/destroy.yml actually need: manage the demo
# stack's resources, plus read/write the state bucket and lock table.
# Not AdministratorAccess — but still fairly broad within these services,
# because Terraform needs to create/read/destroy whatever the module
# defines. Tighten further (e.g. resource-level ARN conditions) if this
# becomes a long-lived, less-trusted pipeline.
data "aws_iam_policy_document" "github_actions" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*",
    ]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.tf_lock.arn]
  }

  statement {
    sid    = "AppInfra"
    effect = "Allow"
    actions = [
      "ec2:*",
      "ecs:*",
      "ecr:*",
      "elasticloadbalancing:*",
      "logs:*",
      "iam:GetRole",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:GetRolePolicy",
      "iam:GetPolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions" {
  name   = "${var.project_name}-github-actions-policy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions.json
}
