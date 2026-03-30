terraform {
  required_version = ">= 1.9"
}

# This module produces a map of BGP-related Ansible variables
# for use with the ingress-node module's extra_ansible_vars input.
# No resources are created here — it is a pure variable aggregation helper.

locals {
  bgp_vars = var.enable_bgp ? {
    enable_bgp     = "true"
    bgp_daemon     = var.bgp_daemon
    anycast_prefix = var.anycast_prefix
    anycast_vip    = var.anycast_vip
    bgp_local_as   = tostring(var.bgp_local_as)
    bgp_peer_as    = tostring(var.bgp_peer_as)
    bgp_peer_ip    = var.bgp_peer_ip
    bgp_router_id  = var.bgp_router_id
    bgp_hold_time  = tostring(var.bgp_hold_time)
    bgp_keepalive  = tostring(var.bgp_keepalive)
    bgp_password   = var.bgp_password
  } : { enable_bgp = "false" }
}
