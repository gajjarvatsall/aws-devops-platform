variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "environment" {
  type    = string
  default = "staging"
}
variable "project_name" {
  type    = string
  default = "cloudops-demo"
}
variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = []
}
variable "nat_gateway_count" {
  type    = number
  default = 2
}
variable "alb_account_id" {
  type    = string
  default = "127311923021"
}
variable "app_port" {
  type    = number
  default = 8080
}
variable "image_tag" {
  type    = string
  default = "bootstrap"
}
variable "certificate_arn" {
  type    = string
  default = ""
}
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "desired_capacity" {
  type    = number
  default = 1
}
variable "min_size" {
  type    = number
  default = 1
}
variable "max_size" {
  type    = number
  default = 4
}
variable "database_engine_version" {
  type    = string
  default = "8.0.39"
}
variable "database_instance_class" {
  type    = string
  default = "db.t4g.small"
}
variable "database_multi_az" {
  type    = bool
  default = true
}
variable "database_backup_retention" {
  type    = number
  default = 14
}
variable "deletion_protection" {
  type    = bool
  default = true
}
variable "force_destroy_buckets" {
  type    = bool
  default = false
}
variable "tags" {
  type    = map(string)
  default = {}
}
