terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
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
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

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

  ingress {
    description = "BSV ingress UDP"
    from_port   = var.listen_port
    to_port     = var.listen_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  ingress {
    description = "Prometheus metrics"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.metrics_allowed_cidrs
  }

  dynamic "ingress" {
    for_each = var.enable_bgp ? [1] : []
    content {
      description = "BGP"
      from_port   = 179
      to_port     = 179
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-sg" })
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
  count    = var.allocate_eips ? var.instance_count : 0
  instance = aws_instance.ingress_node[count.index].id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-eip-${count.index + 1}"
  })
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

  enable_bgp     = var.enable_bgp
  bgp_daemon     = var.bgp_daemon
  anycast_prefix = var.anycast_prefix
  anycast_vip    = var.anycast_vip
  bgp_local_as   = var.bgp_local_as
  bgp_peer_as    = var.bgp_peer_as
  bgp_peer_ip    = var.bgp_peer_ip
  bgp_password   = var.bgp_password
}

# ---------------------------------------------------------------
# Provision each instance via Ansible
# ---------------------------------------------------------------
module "ingress_nodes" {
  source   = "../../modules/ingress-node"
  count    = var.instance_count

  host_ip              = local.node_ips[count.index]
  ssh_user             = "ubuntu"
  ssh_private_key_path = var.ssh_private_key

  shard_bits   = var.shard_bits
  egress_mode  = var.egress_mode
  egress_iface = var.egress_iface

  gre_remote_ip  = var.gre_remote_ip
  gre_local_ip   = local.node_ips[count.index]
  gre_inner_ipv6 = ""

  enable_bgp    = var.enable_bgp
  bgp_peer_ip   = var.bgp_peer_ip
  bgp_router_id = local.node_ips[count.index]

  extra_ansible_vars = module.bgp.bgp_vars

  depends_on = [aws_instance.ingress_node, aws_eip.ingress_node]
}
