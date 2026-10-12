output "vpc_id" { value = aws_vpc.this.id }
output "vpc_cidr" { value = var.vpc_cidr }
output "availability_zones" { value = local.azs }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "app_subnet_ids" { value = aws_subnet.app[*].id }
output "db_subnet_ids" { value = aws_subnet.db[*].id }
output "public_route_table_id" { value = aws_route_table.public.id }
output "app_route_table_ids" { value = aws_route_table.app[*].id }
output "db_route_table_ids" { value = aws_route_table.db[*].id }
output "nat_gateway_ids" { value = aws_nat_gateway.this[*].id }

