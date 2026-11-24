output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  description = "Application subnet IDs"
  value       = aws_subnet.app[*].id
}

output "db_subnet_ids" {
  description = "Database subnet IDs"
  value       = aws_subnet.db[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = try(aws_nat_gateway.this[0].id, null)
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

output "app_route_table_id" {
  value = aws_route_table.app.id
}

output "db_route_table_id" {
  value = aws_route_table.db.id
}