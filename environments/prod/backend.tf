terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_STATE_BUCKET"
    key          = "prod/terraform.tfstate"
    region       = "REPLACE_WITH_STATE_REGION"
    use_lockfile = true
    encrypt      = true
  }
}
