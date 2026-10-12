variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "state_bucket_name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "Use a globally unique, DNS-compatible S3 bucket name."
  }
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "create_github_oidc_role" {
  type    = bool
  default = false
}
variable "github_oidc_provider_arn" {
  type    = string
  default = ""
}
variable "github_repository" {
  type    = string
  default = "ORG/REPOSITORY"
}
variable "github_branch" {
  type    = string
  default = "refs/heads/main"
}
variable "github_environment" {
  type    = string
  default = "staging"
}
