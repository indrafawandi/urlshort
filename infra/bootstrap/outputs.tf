output "github_actions_role_arn" {
  description = "Put this in the GitHub repo as a repository variable: AWS_OIDC_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}

output "state_bucket_name" {
  description = "Put this in the GitHub repo as a repository variable: TF_STATE_BUCKET"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table_name" {
  description = "Put this in the GitHub repo as a repository variable: TF_LOCK_TABLE"
  value       = aws_dynamodb_table.tf_lock.name
}
