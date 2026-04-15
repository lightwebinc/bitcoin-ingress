terraform {
  required_version = ">= 1.9"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Optional: BGP variable aggregation
module "bgp" {
  source = "../../modules/bgp-anycast"

  enable_bgp      = var.enable_bgp
  bgp_daemon      = var.bgp_daemon
  bgp_prefix  = var.bgp_prefix
  bgp_vip     = var.bgp_vip
  bgp_prefix6 = var.bgp_prefix6
  bgp_vip6    = var.bgp_vip6
  bgp_local_as    = var.bgp_local_as
  bgp_peer_as     = var.bgp_peer_as
  bgp_peer_ip     = var.bgp_peer_ip
  bgp_peer_ip6    = var.bgp_peer_ip6
  bgp_password    = var.bgp_password
}

# Provision each host via Ansible
module "ingress_nodes" {
  source   = "../../modules/ingress-node"
  for_each = { for h in var.hosts : h.name => h }

  host_ip              = each.value.public_ip
  ssh_user             = each.value.ssh_user
  ssh_private_key_path = each.value.ssh_key

  shard_bits      = var.shard_bits
  egress_mode     = var.egress_mode
  egress_iface    = var.egress_iface
  mc_route_prefix = var.mc_route_prefix

  gre_local_ip6  = each.value.gre_local_ip6
  gre_remote_ip6 = var.gre_remote_ip6
  gre_inner_ipv6 = each.value.gre_inner_ipv6

  enable_bgp    = var.enable_bgp
  bgp_peer_ip   = each.value.bgp_peer_ip != "" ? each.value.bgp_peer_ip : var.bgp_peer_ip
  bgp_peer_ip6  = each.value.bgp_peer_ip6 != "" ? each.value.bgp_peer_ip6 : var.bgp_peer_ip6
  bgp_router_id = each.value.public_ip

  extra_ansible_vars = module.bgp.bgp_vars
}
