locals {
  github_repository_parts = split("/", var.github_repository)
  github_owner_name       = local.github_repository_parts[0]
  github_repository_name  = local.github_repository_parts[1]
  github_oidc_subject = "repo:${local.github_owner_name}@${var.github_owner_id}/${local.github_repository_name}@${var.github_repository_id}:environment:${var.github_environment}"
}

resource "aws_iam_role" "github_deploy" {
  count = var.create_github_oidc_role ? 1 : 0
  name  = "cloudops-github-terraform-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = var.github_oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = local.github_oidc_subject
        }
      }
    }]
  })
  tags = merge(var.tags, { Component = "github-oidc" })
}
