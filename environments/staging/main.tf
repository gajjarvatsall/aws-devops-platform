data "aws_caller_identity" "current" {}

locals {
  name = "${var.project_name}-${var.environment}"
  tags = merge(var.tags, { Project = var.project_name, Environment = var.environment, Owner = "platform-team" })
}

module "vpc" {
  source             = "../../modules/vpc"
  name               = local.name
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  nat_gateway_count  = var.nat_gateway_count
  tags               = local.tags
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "${local.name}/app"
  tags   = local.tags
}

module "s3" {
  source        = "../../modules/s3"
  name          = local.name
  force_destroy = var.force_destroy_buckets
  tags          = local.tags
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"
  name   = local.name
  tags   = local.tags
}

module "security_groups" {
  source             = "../../modules/security-groups"
  name               = local.name
  vpc_id             = module.vpc.vpc_id
  app_port           = var.app_port
  ecr_repository_arn = module.ecr.repository_arn
  app_log_group_arn  = module.cloudwatch.app_log_group_arn
  app_bucket_arn     = module.s3.app_bucket_arn
  tags               = local.tags
}

module "rds" {
  source                  = "../../modules/rds"
  name                    = local.name
  subnet_ids              = module.vpc.db_subnet_ids
  security_group_ids      = [module.security_groups.db_security_group_id]
  engine_version          = var.database_engine_version
  instance_class          = var.database_instance_class
  backup_retention_period = var.database_backup_retention
  multi_az                = var.database_multi_az
  deletion_protection     = var.deletion_protection
  tags                    = local.tags
}

module "alb" {
  source            = "../../modules/alb"
  name              = local.name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.alb_security_group_id
  logs_bucket_id    = module.s3.alb_logs_bucket_id
  app_port          = var.app_port
  certificate_arn   = var.certificate_arn
  tags              = local.tags
}

resource "aws_iam_role_policy" "secret_read" {
  name = "${local.name}-secret-read"
  role = replace(module.security_groups.ec2_role_arn, "/^.*role\\//", "")
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = module.rds.secret_arn
    }]
  })
}

module "autoscaling" {
  source                = "../../modules/autoscaling"
  name                  = local.name
  subnet_ids            = module.vpc.app_subnet_ids
  security_group_id     = module.security_groups.app_security_group_id
  instance_profile_name = module.security_groups.ec2_instance_profile_name
  target_group_arn      = module.alb.target_group_arn
  ecr_repository_url    = module.ecr.repository_url
  image_tag             = var.image_tag
  app_port              = var.app_port
  instance_type         = var.instance_type
  desired_capacity      = var.desired_capacity
  min_size              = var.min_size
  max_size              = var.max_size
  database_secret_arn   = module.rds.secret_arn
  rds_identifier        = "${local.name}-mysql"
  ecr_repository_name   = module.ecr.repository_name
  region                = var.aws_region
  environment           = var.environment
  log_group_name        = module.cloudwatch.app_log_group_name
  tags                  = local.tags
  depends_on            = [module.rds, aws_iam_role_policy.secret_read]
}

resource "aws_iam_role_policy" "dashboard_read" {
  name = "${local.name}-dashboard-read"
  role = replace(module.security_groups.ec2_role_arn, "/^.*role\\//", "")
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "rds:DescribeDBInstances",
        "ecr:DescribeImages",
      ]
      Resource = "*"
    }]
  })
  depends_on = [module.autoscaling]
}
