output "host_ip" {
  description = "Public IP address of the provisioned ingress node"
  value       = var.host_ip
}

output "inventory_path" {
  description = "Path to the generated Ansible inventory file"
  value       = local.inventory_path
}
