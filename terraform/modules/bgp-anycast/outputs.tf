output "bgp_vars" {
  description = "Map of BGP Ansible variables for use with ingress-node extra_ansible_vars"
  value       = local.bgp_vars
  sensitive   = true
}
