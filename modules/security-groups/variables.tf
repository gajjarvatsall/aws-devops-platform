variable "name" { type = string }
variable "vpc_id" { type = string }
variable "app_port" {
  type    = number
  default = 8080
}
variable "allowed_http" {
  type    = bool
  default = true
}
variable "ecr_repository_arn" { type = string }
variable "image_parameter_arn" { type = string }
variable "app_log_group_arn" { type = string }
variable "app_bucket_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
