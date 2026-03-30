variable "host_ip" {
  description = "Public IP address of the target host"
  type        = string
}

variable "ssh_user" {
  description = "SSH username for the target host"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key file"
  type        = string
}

variable "ansible_playbook_path" {
  description = "Absolute path to the Ansible site.yml playbook"
  type        = string
  default     = ""
}

variable "ansible_inventory_path" {
  description = "Path to write the generated Ansible inventory file"
  type        = string
  default     = ""
}

# Proxy configuration
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

variable "listen_port" {
  description = "UDP port for incoming BSV transaction frames"
  type        = number
  default     = 9000
}

variable "egress_port" {
  description = "UDP port for outgoing multicast datagrams"
  type        = number
  default     = 9001
}

variable "shard_bits" {
  description = "Shard bit width (1-24)"
  type        = number
  default     = 8
}

variable "mc_scope" {
  description = "Multicast scope: link, site, org, or global"
  type        = string
  default     = "site"
}

variable "mc_base_addr" {
  description = "Optional assigned IPv6 base address for multicast groups"
  type        = string
  default     = ""
}

variable "metrics_addr" {
  description = "HTTP bind address for /metrics, /healthz, /readyz"
  type        = string
  default     = ":9100"
}

# Networking configuration
variable "egress_mode" {
  description = "Egress interface mode: ethernet or gre"
  type        = string
  default     = "ethernet"

  validation {
    condition     = contains(["ethernet", "gre"], var.egress_mode)
    error_message = "egress_mode must be 'ethernet' or 'gre'."
  }
}

variable "egress_iface" {
  description = "Egress interface name (or comma-separated list)"
  type        = string
  default     = "eth1"
}

variable "gre_local_ip" {
  description = "Local IP for the GRE tunnel (egress_mode=gre only)"
  type        = string
  default     = ""
}

variable "gre_remote_ip" {
  description = "Remote GRE endpoint IP (egress_mode=gre only)"
  type        = string
  default     = ""
}

variable "gre_inner_ipv6" {
  description = "IPv6 address/prefix for the GRE tunnel interface"
  type        = string
  default     = ""
}

# BGP configuration
variable "enable_bgp" {
  description = "Enable eBGP AnyCast"
  type        = bool
  default     = false
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

variable "anycast_prefix" {
  description = "Shared anycast prefix announced by all nodes"
  type        = string
  default     = ""
}

variable "anycast_vip" {
  description = "Loopback VIP address from the anycast prefix"
  type        = string
  default     = ""
}

variable "bgp_local_as" {
  description = "Local BGP ASN"
  type        = number
  default     = 65001
}

variable "bgp_peer_as" {
  description = "Upstream provider BGP ASN"
  type        = number
  default     = 65000
}

variable "bgp_peer_ip" {
  description = "Upstream BGP peer IP address"
  type        = string
  default     = ""
}

variable "bgp_router_id" {
  description = "BGP router ID (defaults to host IP)"
  type        = string
  default     = ""
}

variable "bgp_password" {
  description = "Optional MD5 BGP session password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "extra_ansible_vars" {
  description = "Additional Ansible variables to pass as --extra-vars"
  type        = map(string)
  default     = {}
}
