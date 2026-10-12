variable "name" { type = string }
variable "vpc_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}
variable "availability_zones" {
  type    = list(string)
  default = []
  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == 2
    error_message = "Provide zero or exactly two availability zones."
  }
}
variable "nat_gateway_count" {
  type    = number
  default = 1
  validation {
    condition     = contains([1, 2], var.nat_gateway_count)
    error_message = "nat_gateway_count must be 1 or 2."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
