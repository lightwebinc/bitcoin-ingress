variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "bitcoin-ingress"
}

variable "environment" {
  description = "Environment tag (e.g. production, staging)"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy subnets and instances into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
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

variable "ssh_private_key" {
  description = "Path to the local SSH private key file"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed to SSH to ingress nodes"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "metrics_allowed_cidrs" {
  description = "CIDR ranges allowed to reach the metrics port (9100)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allocate_eips" {
  description = "Allocate Elastic IPs for each instance (useful for stable or anycast addressing)"
  type        = bool
  default     = false
}

# Proxy configuration
variable "listen_port" {
  description = "UDP port for incoming BSV transaction frames"
  type        = number
  default     = 9000
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
  description = "Egress interface name on the target host"
  type        = string
  default     = "eth1"
}

variable "gre_remote_ip" {
  description = "Remote GRE endpoint IP (egress_mode=gre only)"
  type        = string
  default     = ""
}

# BGP / AnyCast
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
  description = "Upstream BGP peer IP address"
  type        = string
  default     = ""
}

variable "bgp_password" {
  description = "Optional MD5 BGP session password"
  type        = string
  default     = ""
  sensitive   = true
}
