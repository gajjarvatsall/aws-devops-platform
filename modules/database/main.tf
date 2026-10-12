locals { tags = merge(var.tags, { ManagedBy = "Terraform", Component = "database" }) }

resource "random_password" "master" {
  length  = 32
  special = true
}
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/database"
  description             = "RDS credentials for ${var.name}; value is managed by Terraform."
  recovery_window_in_days = 7
  tags                    = local.tags
}
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db"
  subnet_ids = var.subnet_ids
  tags       = merge(local.tags, { Name = "${var.name}-db-subnet-group" })
}
resource "aws_db_instance" "this" {
  identifier                      = "${var.name}-mysql"
  engine                          = "mysql"
  engine_version                  = var.engine_version
  instance_class                  = var.instance_class
  allocated_storage               = var.allocated_storage
  max_allocated_storage           = var.allocated_storage * 2
  db_name                         = var.database_name
  username                        = var.master_username
  password                        = random_password.master.result
  port                            = 3306
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = var.security_group_ids
  publicly_accessible             = false
  storage_encrypted               = true
  backup_retention_period         = var.backup_retention_period
  multi_az                        = var.multi_az
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = var.skip_final_snapshot
  final_snapshot_identifier       = var.skip_final_snapshot ? null : "${var.name}-final"
  apply_immediately               = false
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  tags                            = merge(local.tags, { Name = "${var.name}-mysql" })
}
resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "mysql"
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = var.database_name
  })
}

