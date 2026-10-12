variable "name" { type = string }
variable "subnet_ids" {
  type = list(string)
  validation {
    condition     = length(var.subnet_ids) == 2
    error_message = "Two database subnets are required."
  }
}
variable "security_group_ids" { type = list(string) }
variable "database_name" {
  type    = string
  default = "cloudops"
}
variable "master_username" {
  type    = string
  default = "appadmin"
}
variable "engine_version" {
  type    = string
  default = "8.0.39"
}
variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "backup_retention_period" {
  type    = number
  default = 7
}
variable "multi_az" {
  type    = bool
  default = false
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "skip_final_snapshot" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
