variable "enable_bgp" {
  description = "Enable eBGP"
  type        = bool
  default     = false
}

variable "bgp_daemon" {
  description = "BGP daemon: bird2 or frr"
  type        = string
  default     = "bird2"

  validation {
    condition     = contains(["bird2", "frr"], var.bgp_daemon)
    error_message = "bgp_daemon must be 'bird2' or 'frr'."
  }
}

variable "bgp_prefix" {
  description = "IPv4 shared BGP prefix announced by all nodes (e.g. '192.0.2.0/24')"
  type        = string
  default     = ""
}

variable "bgp_vip" {
  description = "IPv4 loopback BGP VIP (e.g. '192.0.2.1')"
  type        = string
  default     = ""
}

variable "bgp_prefix6" {
  description = "IPv6 shared BGP prefix announced by all nodes (e.g. '2001:db8::/48')"
  type        = string
  default     = ""
}

variable "bgp_vip6" {
  description = "IPv6 loopback BGP VIP (e.g. '2001:db8::1')"
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
  description = "BGP router ID (usually the host's primary IP)"
  type        = string
  default     = ""
}

variable "bgp_hold_time" {
  description = "BGP hold time in seconds"
  type        = number
  default     = 90
}

variable "bgp_keepalive" {
  description = "BGP keepalive interval in seconds"
  type        = number
  default     = 30
}

variable "bgp_password" {
  description = "Optional MD5 BGP session password"
  type        = string
  default     = ""
  sensitive   = true
}
