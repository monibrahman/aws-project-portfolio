# variables.tf
# Terraform "variables" are inputs — they let the same code produce different
# results without editing the code itself (e.g. deploying to a different
# region, or spinning up a "staging" vs "prod" copy of this same
# infrastructure just by changing a value).

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used in tags and resource naming"
  type        = string
  default     = "portfolio"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC — the total IP address range available"
  type        = string
  default     = "10.0.0.0/16"
}

# A /16 CIDR gives us 65,536 IP addresses (10.0.0.0 - 10.0.255.255) to carve
# subnets out of. Way more than we need, but it's the conventional starting
# size — leaves room to grow without redesigning the network later.

variable "availability_zones" {
  description = "Availability Zones to spread subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_instance_class" {
  description = "RDS instance size"
  type        = string
  default     = "db.t4g.micro" # AWS Free Tier eligible
}

# We use TWO AZs (not one) on purpose. AWS Availability Zones are physically
# separate data centers within a region. If we only deployed to one AZ and
# that data center had an outage, our whole app goes down. Spreading across
# two is the minimum for "high availability" — a term you'll want to be able
# to speak to fluently in interviews.
