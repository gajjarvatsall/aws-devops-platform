data "aws_caller_identity" "current" {}
locals {
  name          = "${var.project_name}-${var.environment}"
  tags          = merge(var.tags, { Project = var.project_name, Environment = var.environment, Owner = "platform-team" })
  log_group_arn = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${local.name}/application"
}
module "network" {
  source             = "../../modules/network"
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
module "storage" {
  source         = "../../modules/storage"
  name           = local.name
  alb_account_id = var.alb_account_id
  force_destroy  = var.force_destroy_buckets
  tags           = local.tags
}
module "security" {
  source             = "../../modules/security"
  name               = local.name
  vpc_id             = module.network.vpc_id
  app_port           = var.app_port
  ecr_repository_arn = module.ecr.repository_arn
  app_log_group_arn  = local.log_group_arn
  app_bucket_arn     = module.storage.app_bucket_arn
  tags               = local.tags
}
module "database" {
  source                  = "../../modules/database"
  name                    = local.name
  subnet_ids              = module.network.db_subnet_ids
  security_group_ids      = [module.security.db_security_group_id]
  engine_version          = var.database_engine_version
  instance_class          = var.database_instance_class
  backup_retention_period = var.database_backup_retention
  multi_az                = var.database_multi_az
  deletion_protection     = var.deletion_protection
  tags                    = local.tags
}
resource "aws_iam_role_policy" "secret_read" {
  name = "${local.name}-secret-read"
  role = replace(module.security.ec2_role_arn, "/^.*role\\//", "")
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"], Resource = module.database.secret_arn }]
  })
}
module "compute" {
  source                = "../../modules/compute"
  name                  = local.name
  vpc_id                = module.network.vpc_id
  public_subnet_ids     = module.network.public_subnet_ids
  app_subnet_ids        = module.network.app_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  app_security_group_id = module.security.app_security_group_id
  instance_profile_name = module.security.ec2_instance_profile_name
  ecr_repository_url    = module.ecr.repository_url
  image_tag             = var.image_tag
  certificate_arn       = var.certificate_arn
  app_port              = var.app_port
  instance_type         = var.instance_type
  desired_capacity      = var.desired_capacity
  min_size              = var.min_size
  max_size              = var.max_size
  database_secret_arn   = module.database.secret_arn
  region                = var.aws_region
  environment           = var.environment
  alb_logs_bucket_id    = module.storage.alb_logs_bucket_id
  tags                  = local.tags
  depends_on            = [module.database, aws_iam_role_policy.secret_read]
}

