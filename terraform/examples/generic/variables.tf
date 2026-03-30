variable "hosts" {
  description = "List of target hosts to provision. Per-host optional fields: gre_local_ip6 (local IPv6 tunnel endpoint), gre_inner_ipv6 (inner tunnel address), bgp_peer_ip (IPv4 BGP peer override), bgp_peer_ip6 (IPv6 BGP peer override)."
  type = list(object({
    name           = string
    public_ip      = string
    ssh_user       = string
    ssh_key        = string
    gre_local_ip6  = optional(string, "")
    gre_inner_ipv6 = optional(string, "")
    bgp_peer_ip    = optional(string, "")
    bgp_peer_ip6   = optional(string, "")
  }))
}

variable "shard_bits" {
  description = "Shard bit width (1-24)"
  type        = number
  default     = 8
}

variable "egress_mode" {
  description = "Egress interface mode: ethernet or gre"
  type        = string
  default     = "ethernet"
}

variable "egress_iface" {
  description = "Egress interface name"
  type        = string
  default     = "eth1"
}

variable "gre_remote_ip6" {
  description = "Remote IPv6 endpoint for ip6gre tunnel (egress_mode=gre only, shared across all hosts)"
  type        = string
  default     = ""
}

variable "enable_bgp" {
  description = "Enable eBGP AnyCast"
  type        = bool
  default     = false
}

variable "bgp_daemon" {
  description = "BGP daemon: bird2 or frr"
  type        = string
  default     = "bird2"
}

variable "anycast_prefix" {
  description = "IPv4 shared anycast prefix announced by all nodes"
  type        = string
  default     = ""
}

variable "anycast_vip" {
  description = "IPv4 loopback VIP from the anycast prefix"
  type        = string
  default     = ""
}

variable "anycast_prefix6" {
  description = "IPv6 shared anycast prefix announced by all nodes (e.g. '2001:db8::/48')"
  type        = string
  default     = ""
}

variable "anycast_vip6" {
  description = "IPv6 loopback VIP from anycast_prefix6 (e.g. '2001:db8::1')"
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
  description = "Upstream BGP peer IPv4 address (default, overridable per host)"
  type        = string
  default     = ""
}

variable "bgp_peer_ip6" {
  description = "Upstream BGP peer IPv6 address (default, overridable per host)"
  type        = string
  default     = ""
}

variable "bgp_password" {
  description = "Optional MD5 BGP session password"
  type        = string
  default     = ""
  sensitive   = true
}
