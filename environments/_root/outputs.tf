output "vpc_id" { value = module.network.vpc_id }
output "ecr_repository_url" { value = module.ecr.repository_url }
output "database_endpoint" {
  value     = module.database.endpoint
  sensitive = true
}
output "database_secret_arn" { value = module.database.secret_arn }
output "alb_dns_name" { value = module.compute.load_balancer_dns_name }
output "target_group_arn" { value = module.compute.target_group_arn }
output "application_log_group" { value = module.compute.log_group_name }
