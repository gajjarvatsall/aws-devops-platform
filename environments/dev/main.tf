module "environment" {
  source                    = "../_root"
  aws_region                = var.aws_region
  environment               = var.environment
  project_name              = var.project_name
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  nat_gateway_count         = var.nat_gateway_count
  alb_account_id            = var.alb_account_id
  app_port                  = var.app_port
  image_tag                 = var.image_tag
  certificate_arn           = var.certificate_arn
  instance_type             = var.instance_type
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  database_engine_version   = var.database_engine_version
  database_instance_class   = var.database_instance_class
  database_multi_az         = var.database_multi_az
  database_backup_retention = var.database_backup_retention
  deletion_protection       = var.deletion_protection
  force_destroy_buckets     = var.force_destroy_buckets
  tags                      = var.tags
}

