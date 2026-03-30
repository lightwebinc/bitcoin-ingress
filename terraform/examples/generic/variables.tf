variable "hosts" {
  description = "List of target hosts to provision"
  type = list(object({
    name      = string
    public_ip = string
    ssh_user  = string
    ssh_key   = string
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

variable "gre_remote_ip" {
  description = "Remote GRE endpoint IP (egress_mode=gre only)"
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
  description = "Shared anycast prefix announced by all nodes"
  type        = string
  default     = ""
}

variable "anycast_vip" {
  description = "Loopback VIP from the anycast prefix"
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
  description = "Upstream BGP peer IP (default, overridable per host)"
  type        = string
  default     = ""
}

variable "bgp_password" {
  description = "Optional MD5 BGP session password"
  type        = string
  default     = ""
  sensitive   = true
}
