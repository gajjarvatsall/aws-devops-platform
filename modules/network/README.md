# Network module

Creates a DNS-enabled VPC with two public, application, and database subnets
across data-source-selected Availability Zones. `nat_gateway_count = 1` is the
cost-conscious default; use `2` for one NAT Gateway per AZ.

