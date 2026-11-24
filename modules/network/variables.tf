variable "name" {
  type        = string
  description = "Environment/project name"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs"
}

variable "app_subnet_cidrs" {
  type        = list(string)
  description = "Application subnet CIDRs"
}

variable "db_subnet_cidrs" {
  type        = list(string)
  description = "Database subnet CIDRs"
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Create NAT Gateway"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Common resource tags"
  default     = {}
}