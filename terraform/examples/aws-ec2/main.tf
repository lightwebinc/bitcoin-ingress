terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
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

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------
# Data: latest Ubuntu 24.04 AMI
# ---------------------------------------------------------------
data "aws_ami" "ubuntu_24_04" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------
# VPC and networking
# ---------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = true

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                           = length(var.availability_zones)
  vpc_id                          = aws_vpc.main.id
  cidr_block                      = cidrsubnet(var.vpc_cidr, 4, count.index)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)
  availability_zone               = var.availability_zones[count.index]
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-public-${count.index}" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------
# Security group
# ---------------------------------------------------------------
resource "aws_security_group" "ingress_node" {
  name        = "${var.name_prefix}-ingress-node"
  description = "bitcoin-ingress proxy node"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "bsv_udp" {
  security_group_id = aws_security_group.ingress_node.id
  description       = "BSV ingress UDP (IPv4)"
  from_port         = var.listen_port
  to_port           = var.listen_port
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "bsv_udp6" {
  security_group_id = aws_security_group.ingress_node.id
  description       = "BSV ingress UDP (IPv6)"
  from_port         = var.listen_port
  to_port           = var.listen_port
  ip_protocol       = "udp"
  cidr_ipv6         = "::/0"
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.ssh_allowed_cidrs)

  security_group_id = aws_security_group.ingress_node.id
  description       = "SSH management"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "metrics" {
  for_each = toset(var.metrics_allowed_cidrs)

  security_group_id = aws_security_group.ingress_node.id
  description       = "Prometheus metrics"
  from_port         = 9100
  to_port           = 9100
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "bgp4" {
  count = var.enable_bgp && var.bgp_peer_ip != "" ? 1 : 0

  security_group_id = aws_security_group.ingress_node.id
  description       = "BGP (IPv4)"
  from_port         = 179
  to_port           = 179
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "bgp6" {
  count = var.enable_bgp && var.bgp_peer_ip6 != "" ? 1 : 0

  security_group_id = aws_security_group.ingress_node.id
  description       = "BGP (IPv6)"
  from_port         = 179
  to_port           = 179
  ip_protocol       = "tcp"
  cidr_ipv6         = "::/0"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.ingress_node.id
  description       = "Allow all outbound (IPv4)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "all6" {
  security_group_id = aws_security_group.ingress_node.id
  description       = "Allow all outbound (IPv6)"
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
}

# ---------------------------------------------------------------
# EC2 instances
# ---------------------------------------------------------------
resource "aws_instance" "ingress_node" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu_24_04.id
  instance_type = var.instance_type
  key_name      = var.key_name
  subnet_id     = aws_subnet.public[count.index % length(aws_subnet.public)].id

  vpc_security_group_ids = [aws_security_group.ingress_node.id]

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-node-${count.index + 1}"
  })
}

# Optional Elastic IPs (for AnyCast or stable inbound addressing)
resource "aws_eip" "ingress_node" {
  count  = var.allocate_eips ? var.instance_count : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-eip-${count.index + 1}"
  })
}

resource "aws_eip_association" "ingress_node" {
  count         = var.allocate_eips ? var.instance_count : 0
  instance_id   = aws_instance.ingress_node[count.index].id
  allocation_id = aws_eip.ingress_node[count.index].id
}

locals {
  common_tags = {
    Project     = "bitcoin-ingress"
    ManagedBy   = "terraform"
    Environment = var.environment
  }

  # Use EIP if allocated, otherwise use the public IP assigned to the instance
  node_ips = var.allocate_eips ? [for eip in aws_eip.ingress_node : eip.public_ip] : [
    for inst in aws_instance.ingress_node : inst.public_ip
  ]
}

# ---------------------------------------------------------------
# BGP AnyCast variable aggregation
# ---------------------------------------------------------------
module "bgp" {
  source = "../../modules/bgp-anycast"

  enable_bgp      = var.enable_bgp
  bgp_daemon      = var.bgp_daemon
  anycast_prefix  = var.anycast_prefix
  anycast_vip     = var.anycast_vip
  anycast_prefix6 = var.anycast_prefix6
  anycast_vip6    = var.anycast_vip6
  bgp_local_as    = var.bgp_local_as
  bgp_peer_as     = var.bgp_peer_as
  bgp_peer_ip     = var.bgp_peer_ip
  bgp_peer_ip6    = var.bgp_peer_ip6
  bgp_password    = var.bgp_password
}

# ---------------------------------------------------------------
# Provision each instance via Ansible
# ---------------------------------------------------------------
module "ingress_nodes" {
  source = "../../modules/ingress-node"
  count  = var.instance_count

  host_ip              = local.node_ips[count.index]
  ssh_user             = "ubuntu"
  ssh_private_key_path = var.ssh_private_key

  shard_bits   = var.shard_bits
  egress_mode  = var.egress_mode
  egress_iface = var.egress_iface

  gre_remote_ip6 = var.gre_remote_ip6
  gre_local_ip6  = local.node_ips[count.index]
  gre_inner_ipv6 = ""

  enable_bgp    = var.enable_bgp
  bgp_peer_ip   = var.bgp_peer_ip
  bgp_peer_ip6  = var.bgp_peer_ip6
  bgp_router_id = local.node_ips[count.index]

  extra_ansible_vars = module.bgp.bgp_vars

  depends_on = [aws_instance.ingress_node, aws_eip.ingress_node]
}
