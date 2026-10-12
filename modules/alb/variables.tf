variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "logs_bucket_id" { type = string }
variable "app_port" { type = number }
variable "health_check_path" {
  type    = string
  default = "/health"
}
variable "certificate_arn" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
