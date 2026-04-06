################################################################################
# AWS VPC Module — Outputs
################################################################################

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = aws_vpc.main.arn
}

output "vpc_cidr_block" {
  description = "The primary CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs (index matches AZ order)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs (index matches AZ order)."
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "List of isolated data subnet IDs."
  value       = aws_subnet.data[*].id
}

output "public_subnet_cidr_blocks" {
  description = "List of public subnet CIDR blocks."
  value       = aws_subnet.public[*].cidr_block
}

output "private_subnet_cidr_blocks" {
  description = "List of private subnet CIDR blocks."
  value       = aws_subnet.private[*].cidr_block
}

output "data_subnet_cidr_blocks" {
  description = "List of data subnet CIDR blocks."
  value       = aws_subnet.data[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs."
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of Elastic IPs assigned to NAT Gateways."
  value       = aws_eip.nat[*].public_ip
}

output "private_route_table_ids" {
  description = "List of private route table IDs."
  value       = aws_route_table.private[*].id
}

output "flow_log_cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group receiving VPC Flow Logs."
  value       = aws_cloudwatch_log_group.flow_logs.arn
}

output "s3_endpoint_id" {
  description = "ID of the S3 Gateway VPC Endpoint (null if disabled)."
  value       = var.enable_s3_endpoint ? aws_vpc_endpoint.s3[0].id : null
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB Gateway VPC Endpoint (null if disabled)."
  value       = var.enable_dynamodb_endpoint ? aws_vpc_endpoint.dynamodb[0].id : null
}
