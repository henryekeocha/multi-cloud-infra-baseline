################################################################################
# AWS VPC Module — Variables
################################################################################

variable "aws_region" {
  description = "AWS region where the VPC will be created."
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC. Used as a prefix for all child resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC (e.g. 10.0.0.0/16)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

###############################################################################
# Subnets
###############################################################################

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ). These subnets host load balancers and NAT Gateway EIPs."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ). Application workloads and EKS nodes run here."
  type        = list(string)
  default     = []
}

variable "data_subnet_cidrs" {
  description = "List of CIDR blocks for isolated data subnets (one per AZ). RDS, ElastiCache, and other data services run here with no internet route."
  type        = list(string)
  default     = []
}

###############################################################################
# NAT Gateway
###############################################################################

variable "enable_nat_gateway" {
  description = "Whether to create NAT Gateways for private subnet egress."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway instead of one per AZ. Reduces cost for non-production environments at the expense of HA."
  type        = bool
  default     = false
}

###############################################################################
# VPC Flow Logs
###############################################################################

variable "flow_log_retention_days" {
  description = "Retention period (in days) for VPC Flow Log CloudWatch log group."
  type        = number
  default     = 90

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.flow_log_retention_days)
    error_message = "flow_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "flow_log_kms_key_arn" {
  description = "ARN of a KMS key to encrypt VPC Flow Logs in CloudWatch. Null uses the AWS managed key."
  type        = string
  default     = null
}

###############################################################################
# VPC Endpoints
###############################################################################

variable "enable_s3_endpoint" {
  description = "Create a Gateway VPC Endpoint for S3. Eliminates S3 traffic from traversing the internet."
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Create a Gateway VPC Endpoint for DynamoDB."
  type        = bool
  default     = true
}

###############################################################################
# Tags
###############################################################################

variable "tags" {
  description = "Map of tags applied to all resources. Minimum recommended: Environment, Owner, CostCenter."
  type        = map(string)
  default     = {}
}
