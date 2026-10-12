resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = merge(var.tags, { ManagedBy = "Terraform", Component = "ecr" })
}
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep recent release images"
        selection    = { tagStatus = "tagged", tagPrefixList = ["v"], countType = "imageCountMoreThan", countNumber = 20 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire old commit images"
        selection    = { tagStatus = "tagged", tagPrefixList = ["sha-"], countType = "sinceImagePushed", countUnit = "days", countNumber = 30 }
        action       = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Expire untagged images"
        selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
        action       = { type = "expire" }
      }
    ]
  })
}
