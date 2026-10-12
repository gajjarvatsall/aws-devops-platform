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
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_repository}:ref:${var.github_branch}",
            "repo:${var.github_repository}:environment:${var.github_environment}",
          ]
        }
      }
    }]
  })
  tags = merge(var.tags, { Component = "github-oidc" })
}
