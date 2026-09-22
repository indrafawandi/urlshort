variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project_name" {
  type    = string
  default = "urlshort"
}

variable "state_bucket_name" {
  description = "Globally unique S3 bucket name for Terraform state. Change the default — 'urlshort-tfstate' is almost certainly taken."
  type        = string
}

variable "lock_table_name" {
  type    = string
  default = "urlshort-tfstate-lock"
}

variable "github_org" {
  description = "Your GitHub username or org, e.g. 'fawandi'."
  type        = string
}

variable "github_repo" {
  description = "The repo name, e.g. 'urlshort'."
  type        = string
}
