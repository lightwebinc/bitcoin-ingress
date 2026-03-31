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

locals {
  ansible_playbook = var.ansible_playbook_path != "" ? var.ansible_playbook_path : "${path.module}/../../../ansible/site.yml"
  inventory_path   = var.ansible_inventory_path != "" ? var.ansible_inventory_path : "${path.root}/generated-inventory-${replace(var.host_ip, ".", "-")}.yml"
  bgp_router_id    = var.bgp_router_id != "" ? var.bgp_router_id : var.host_ip

  ansible_extra_vars = merge(
    {
      proxy_repo      = var.proxy_repo
      proxy_version   = var.proxy_version
      listen_port     = tostring(var.listen_port)
      egress_port     = tostring(var.egress_port)
      shard_bits      = tostring(var.shard_bits)
      mc_scope        = var.mc_scope
      mc_base_addr    = var.mc_base_addr
      mc_route_prefix = var.mc_route_prefix
      metrics_addr    = var.metrics_addr
      egress_mode     = var.egress_mode
      egress_iface    = var.egress_iface
      gre_local_ip6   = var.gre_local_ip6
      gre_remote_ip6  = var.gre_remote_ip6
      gre_inner_ipv6  = var.gre_inner_ipv6
      enable_bgp      = tostring(var.enable_bgp)
      bgp_daemon      = var.bgp_daemon
      anycast_prefix  = var.anycast_prefix
      anycast_vip     = var.anycast_vip
      anycast_prefix6 = var.anycast_prefix6
      anycast_vip6    = var.anycast_vip6
      bgp_local_as    = tostring(var.bgp_local_as)
      bgp_peer_as     = tostring(var.bgp_peer_as)
      bgp_peer_ip     = var.bgp_peer_ip
      bgp_peer_ip6    = var.bgp_peer_ip6
      bgp_router_id   = local.bgp_router_id
      bgp_password    = var.bgp_password
    },
    var.extra_ansible_vars
  )
}

# Generate a per-host Ansible inventory file
resource "local_file" "inventory" {
  filename        = local.inventory_path
  file_permission = "0600"
  content         = <<-INVENTORY
    all:
      children:
        ingress_nodes:
          hosts:
            ${var.host_ip}:
              ansible_host: ${var.host_ip}
              ansible_user: ${var.ssh_user}
              ansible_ssh_private_key_file: ${var.ssh_private_key_path}
              ansible_ssh_common_args: '-o StrictHostKeyChecking=accept-new'
  INVENTORY
}

# Run Ansible playbook against the target host
resource "null_resource" "provision" {
  triggers = {
    host_ip    = var.host_ip
    extra_vars = jsonencode(local.ansible_extra_vars)
  }

  depends_on = [local_file.inventory]

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook \
        -i ${local.inventory_path} \
        ${local.ansible_playbook} \
        --extra-vars '${jsonencode(local.ansible_extra_vars)}'
    EOT
  }
}
