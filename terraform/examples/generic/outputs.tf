output "provisioned_hosts" {
  description = "IPs of all provisioned ingress nodes"
  value       = { for k, v in module.ingress_nodes : k => v.host_ip }
}
