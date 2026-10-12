data "aws_availability_zones" "available" { state = "available" }

locals {
  azs          = length(var.availability_zones) == 2 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 2)
  public_cidrs = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  app_cidrs    = [cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]
  db_cidrs     = [cidrsubnet(var.vpc_cidr, 4, 4), cidrsubnet(var.vpc_cidr, 4, 5)]
  tags         = merge(var.tags, { ManagedBy = "Terraform", Component = "vpc" })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = "${var.name}-vpc" })
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-igw" })
}
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = "${var.name}-public-${count.index + 1}", Tier = "public", "kubernetes.io/role/elb" = "1" })
}
resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.app_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(local.tags, { Name = "${var.name}-app-${count.index + 1}", Tier = "application", "kubernetes.io/role/internal-elb" = "1" })
}
resource "aws_subnet" "db" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.db_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(local.tags, { Name = "${var.name}-db-${count.index + 1}", Tier = "database" })
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = merge(local.tags, { Name = "${var.name}-public-rt" })
}
resource "aws_route_table_association" "public" {
  count          = 2
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.public[count.index].id
}
resource "aws_eip" "nat" {
  count  = var.nat_gateway_count
  domain = "vpc"
  tags   = merge(local.tags, { Name = "${var.name}-nat-eip-${count.index + 1}" })
}
resource "aws_nat_gateway" "this" {
  count         = var.nat_gateway_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.nat_gateway_count == 1 ? 0 : count.index].id
  depends_on    = [aws_internet_gateway.this]
  tags          = merge(local.tags, { Name = "${var.name}-nat-${count.index + 1}" })
}
resource "aws_route_table" "app" {
  count  = 2
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[var.nat_gateway_count == 1 ? 0 : count.index].id
  }
  tags = merge(local.tags, { Name = "${var.name}-app-rt-${count.index + 1}" })
}
resource "aws_route_table_association" "app" {
  count          = 2
  route_table_id = aws_route_table.app[count.index].id
  subnet_id      = aws_subnet.app[count.index].id
}
resource "aws_route_table" "db" {
  count  = 2
  vpc_id = aws_vpc.this.id
  tags   = merge(local.tags, { Name = "${var.name}-db-rt-${count.index + 1}" })
}
resource "aws_route_table_association" "db" {
  count          = 2
  route_table_id = aws_route_table.db[count.index].id
  subnet_id      = aws_subnet.db[count.index].id
}
