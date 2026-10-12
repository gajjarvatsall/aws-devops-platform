variable "name" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "instance_profile_name" { type = string }
variable "target_group_arn" { type = string }
variable "ecr_repository_url" { type = string }
variable "image_tag" {
  type    = string
  default = "bootstrap"
}
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
variable "database_secret_arn" { type = string }
variable "rds_identifier" { type = string }
variable "ecr_repository_name" { type = string }
variable "region" { type = string }
variable "environment" { type = string }
variable "log_group_name" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
