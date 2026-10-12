locals { tags = merge(var.tags, { ManagedBy = "Terraform", Component = "cloudwatch" }) }

resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/ec2/${var.name}/application"
  retention_in_days = var.retention_days
  tags              = local.tags
}
