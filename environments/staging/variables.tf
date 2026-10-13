variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "terraform_state_bucket" {
  type    = string
  default = "aws-vg-cloudops-tf-state"
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
