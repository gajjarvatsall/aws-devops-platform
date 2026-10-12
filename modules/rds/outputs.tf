output "endpoint" { value = aws_db_instance.this.address }
output "port" { value = aws_db_instance.this.port }
output "database_name" { value = var.database_name }
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "security_group_id" { value = one(var.security_group_ids) }

