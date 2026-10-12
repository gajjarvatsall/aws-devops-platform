output "vpc_id" { value = module.vpc.vpc_id }
output "ecr_repository_url" { value = module.ecr.repository_url }
output "database_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}
output "database_secret_arn" { value = module.rds.secret_arn }
output "alb_dns_name" { value = module.alb.load_balancer_dns_name }
output "target_group_arn" { value = module.alb.target_group_arn }
output "application_log_group" { value = module.cloudwatch.app_log_group_name }
