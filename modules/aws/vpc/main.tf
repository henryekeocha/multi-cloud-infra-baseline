################################################################################
# AWS VPC Module — Main
#
# Creates a multi-AZ VPC with public + private subnets, NAT Gateways,
# VPC Flow Logs to CloudWatch, and a tightly-scoped security group baseline.
# Mirrors the project's GCP VPC module structure for cross-cloud comparison.
#
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# VPC
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true   # required for Private Hosted Zones
  enable_dns_hostnames = true   # required for EKS node registration

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

###############################################################################
# VPC Flow Logs → CloudWatch (CKV_AWS_73, HIPAA §164.312(b))
###############################################################################

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/vpc/${var.vpc_name}/flow-logs"
  retention_in_days = var.flow_log_retention_days
  kms_key_id        = var.flow_log_kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-flow-logs"
  })
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.vpc_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.vpc_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-flow-log"
  })
}

###############################################################################
# Internet Gateway
###############################################################################

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

###############################################################################
# Public Subnets
###############################################################################

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false # explicit EIP assignment only — CKV_AWS_130

  tags = merge(var.tags, {
    Name                     = "${var.vpc_name}-public-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/role/elb" = "1" # EKS external load balancer discovery
    Tier                     = "public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# NAT Gateways (one per AZ for HA)
###############################################################################

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.private_subnet_cidrs)) : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-eip-${count.index}"
  })
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-nat-${count.index}"
  })

  depends_on = [aws_internet_gateway.main]
}

###############################################################################
# Private Subnets
###############################################################################

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name                              = "${var.vpc_name}-private-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/role/internal-elb" = "1" # EKS internal load balancer discovery
    Tier                              = "private"
  })
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? length(var.private_subnet_cidrs) : 1
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-rt-${count.index}"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

###############################################################################
# Data Subnets (isolated — no route to internet)
###############################################################################

resource "aws_subnet" "data" {
  count = length(var.data_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.data_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-data-${data.aws_availability_zones.available.names[count.index]}"
    Tier = "data"
  })
}

resource "aws_route_table" "data" {
  count  = length(var.data_subnet_cidrs) > 0 ? 1 : 0
  vpc_id = aws_vpc.main.id
  # Intentionally no routes — data tier has no internet access

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-data-rt"
  })
}

resource "aws_route_table_association" "data" {
  count          = length(aws_subnet.data)
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data[0].id
}

###############################################################################
# VPC Endpoints (Gateway type — free, no data transfer charge)
###############################################################################

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_endpoint ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, aws_route_table.data[*].id)

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-s3-endpoint"
  })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count = var.enable_dynamodb_endpoint ? 1 : 0

  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(aws_route_table.private[*].id, aws_route_table.data[*].id)

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-dynamodb-endpoint"
  })
}

###############################################################################
# Default Security Group — lock down (CKV_AWS_148)
###############################################################################

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # No ingress or egress rules — all traffic denied by default

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-default-sg-DO-NOT-USE"
  })
}

###############################################################################
# Network ACLs
###############################################################################

resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  # Deny all — explicit NACLs applied to each subnet tier
  tags = merge(var.tags, {
    Name = "${var.vpc_name}-default-nacl-DO-NOT-USE"
  })
}
