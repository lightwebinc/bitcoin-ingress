output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.ingress_node[*].id
}

output "node_ips" {
  description = "Public IP addresses of all ingress nodes"
  value       = local.node_ips
}

output "elastic_ips" {
  description = "Elastic IP addresses (if allocated)"
  value       = var.allocate_eips ? aws_eip.ingress_node[*].public_ip : []
}

output "security_group_id" {
  description = "Security group ID for ingress nodes"
  value       = aws_security_group.ingress_node.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
