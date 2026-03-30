variable "enable_bgp" {
  description = "Enable eBGP AnyCast"
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

variable "anycast_prefix" {
  description = "Shared prefix announced by all nodes (e.g. '192.0.2.0/24')"
  type        = string
  default     = ""
}

variable "anycast_vip" {
  description = "Loopback VIP from the anycast prefix (e.g. '192.0.2.1')"
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
  description = "Upstream BGP peer IP"
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
