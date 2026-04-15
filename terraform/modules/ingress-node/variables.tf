variable "ansible_inventory_path" {
  description = "Path to write the generated Ansible inventory file"
  type        = string
  default     = ""
}

variable "ansible_playbook_path" {
  description = "Absolute path to the Ansible site.yml playbook"
  type        = string
  default     = ""
}

variable "host_ip" {
  description = "Public IP address of the target host"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for the target host"
  type        = string
  default     = "ubuntu"
}

# Proxy configuration
variable "egress_port" {
  description = "UDP port for outgoing multicast datagrams"
  type        = number
  default     = 9001
}

variable "listen_port" {
  description = "UDP port for incoming BSV transaction frames"
  type        = number
  default     = 9000
}

variable "mc_base_addr" {
  description = "Optional assigned IPv6 base address for multicast groups"
  type        = string
  default     = ""
}

variable "mc_route_prefix" {
  description = "IPv6 multicast route prefix for the egress interface (empty = auto-derive from mc_scope)"
  type        = string
  default     = ""
}

variable "mc_scope" {
  description = "Multicast scope: link, site, org, or global"
  type        = string
  default     = "site"
}

variable "metrics_addr" {
  description = "HTTP bind address for /metrics, /healthz, /readyz"
  type        = string
  default     = ":9100"
}

variable "proxy_repo" {
  description = "Git URL of the bitcoin-shard-proxy repository"
  type        = string
  default     = "https://github.com/lightwebinc/bitcoin-shard-proxy.git"
}

variable "proxy_version" {
  description = "Git ref (branch, tag, or SHA) to check out"
  type        = string
  default     = "main"
}

variable "shard_bits" {
  description = "Shard bit width (1-24)"
  type        = number
  default     = 8
}

# Networking configuration
variable "egress_iface" {
  description = "Egress interface name (or comma-separated list)"
  type        = string
  default     = "eth1"
}

variable "egress_mode" {
  description = "Egress interface mode: ethernet or gre"
  type        = string
  default     = "ethernet"

  validation {
    condition     = contains(["ethernet", "gre"], var.egress_mode)
    error_message = "egress_mode must be 'ethernet' or 'gre'."
  }
}

variable "gre_inner_ipv6" {
  description = "IPv6 address/prefix assigned to the tunnel interface"
  type        = string
  default     = ""
}

variable "gre_local_ip6" {
  description = "Local IPv6 address for the ip6gre tunnel endpoint (egress_mode=gre only)"
  type        = string
  default     = ""
}

variable "gre_remote_ip6" {
  description = "Remote IPv6 address for the ip6gre tunnel endpoint (egress_mode=gre only)"
  type        = string
  default     = ""
}

# BGP configuration
variable "bgp_prefix" {
  description = "IPv4 shared BGP prefix announced by all nodes"
  type        = string
  default     = ""
}

variable "bgp_prefix6" {
  description = "IPv6 shared BGP prefix announced by all nodes (e.g. '2001:db8::/48')"
  type        = string
  default     = ""
}

variable "bgp_vip" {
  description = "IPv4 loopback BGP VIP"
  type        = string
  default     = ""
}

variable "bgp_vip6" {
  description = "IPv6 loopback BGP VIP (e.g. '2001:db8::1')"
  type        = string
  default     = ""
}

variable "bgp_daemon" {
  description = "BGP daemon to use: bird2 or frr"
  type        = string
  default     = "bird2"

  validation {
    condition     = contains(["bird2", "frr"], var.bgp_daemon)
    error_message = "bgp_daemon must be 'bird2' or 'frr'."
  }
}

variable "bgp_local_as" {
  description = "Local BGP ASN"
  type        = number
  default     = 65001
}

variable "bgp_password" {
  description = "Optional MD5 BGP session password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "bgp_peer_as" {
  description = "Upstream provider BGP ASN"
  type        = number
  default     = 65000
}

variable "bgp_peer_ip" {
  description = "Upstream BGP peer IPv4 address (leave empty for IPv6-only peer)"
  type        = string
  default     = ""
}

variable "bgp_peer_ip6" {
  description = "Upstream BGP peer IPv6 address"
  type        = string
  default     = ""
}

variable "bgp_router_id" {
  description = "BGP router ID (defaults to host IP)"
  type        = string
  default     = ""
}

variable "enable_bgp" {
  description = "Enable eBGP"
  type        = bool
  default     = false
}

variable "extra_ansible_vars" {
  description = "Additional Ansible variables to pass as --extra-vars"
  type        = map(string)
  default     = {}
}
