variable "allocate_eips" {
  description = "Allocate Elastic IPs for each instance (useful for stable BGP VIP addressing)"
  type        = bool
  default     = false
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets and instances into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "instance_count" {
  description = "Number of EC2 ingress nodes to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the AWS EC2 key pair for SSH access"
  type        = string
}

variable "metrics_allowed_cidrs" {
  description = "CIDR ranges allowed to reach the metrics port (9100)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "bitcoin-ingress"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed to SSH to ingress nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_private_key" {
  description = "Path to the local SSH private key file"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

# Proxy configuration
variable "egress_iface" {
  description = "Egress interface name on the target host"
  type        = string
  default     = "eth1"
}

variable "egress_mode" {
  description = "Egress interface mode: ethernet or gre"
  type        = string
  default     = "ethernet"
}

variable "gre_remote_ip6" {
  description = "Remote IPv6 endpoint for ip6gre tunnel (egress_mode=gre only)"
  type        = string
  default     = ""
}

variable "listen_port" {
  description = "UDP port for incoming BSV transaction frames"
  type        = number
  default     = 9000
}

variable "mc_route_prefix" {
  description = "IPv6 multicast route prefix for the egress interface (empty = auto-derive from mc_scope)"
  type        = string
  default     = ""
}

variable "shard_bits" {
  description = "Shard bit width (1-24)"
  type        = number
  default     = 8
}

# BGP
variable "bgp_prefix" {
  description = "IPv4 BGP prefixes announced by all nodes"
  type        = list(string)
  default     = []
}

variable "bgp_prefix6" {
  description = "IPv6 BGP prefixes announced by all nodes (e.g. ['2001:db8::/48'])"
  type        = list(string)
  default     = []
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
  description = "BGP daemon: bird2 or frr"
  type        = string
  default     = "bird2"
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

variable "enable_bgp" {
  description = "Enable eBGP"
  type        = bool
  default     = false
}
