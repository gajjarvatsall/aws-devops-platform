variable "name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "app_subnet_ids" { type = list(string) }
variable "alb_security_group_id" { type = string }
variable "app_security_group_id" { type = string }
variable "instance_profile_name" { type = string }
variable "ecr_repository_url" { type = string }
variable "image_tag" {
  type    = string
  default = "bootstrap"
}
variable "certificate_arn" { type = string }
variable "app_port" {
  type    = number
  default = 8080
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "desired_capacity" {
  type    = number
  default = 0
}
variable "min_size" {
  type    = number
  default = 0
}
variable "max_size" {
  type    = number
  default = 4
}
variable "root_volume_size" {
  type    = number
  default = 20
}
variable "health_check_path" {
  type    = string
  default = "/health"
}
variable "log_retention_days" {
  type    = number
  default = 30
}
variable "database_secret_arn" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "alb_logs_bucket_id" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
