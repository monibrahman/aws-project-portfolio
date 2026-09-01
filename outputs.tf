# outputs.tf
# Outputs print values to your terminal after `terraform apply` finishes,
# and let other Terraform files (or future modules) reference these
# resources without hardcoding IDs.

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "db_endpoint" {
  description = "RDS connection endpoint (hostname:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_username" {
  description = "RDS master username"
  value       = aws_db_instance.main.username
}

output "db_password" {
  description = "RDS master password (auto-generated)"
  value       = random_password.db.result
  sensitive   = true
  # `sensitive = true` hides this from regular terraform apply/plan console
  # output — it'll show as (sensitive value) instead of the real string.
  # To actually retrieve it when you need it, run:
  #   terraform output -raw db_password
}

output "api_endpoint" {
  description = "Base URL of the API Gateway"
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/health"
}
