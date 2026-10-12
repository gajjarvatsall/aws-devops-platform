output "state_bucket_name" { value = aws_s3_bucket.state.id }
output "state_bucket_arn" { value = aws_s3_bucket.state.arn }
output "state_bucket_region" { value = var.aws_region }
output "github_deploy_role_arn" {
  value = var.create_github_oidc_role ? aws_iam_role.github_deploy[0].arn : null
}
