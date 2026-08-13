module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "microservices-free-vpc"
  cidr = "10.0.0.0/16" # Private network range providing up to 65,536 addresses

  azs              = ["ap-south-1a", "ap-south-1b"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"] # Used for Load Balancer and Public Compute Nodes
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24"] # Isolated database subnets

  # CRITICAL FOR FREE TIER: Disable NAT Gateways to save ~$65/month
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  enable_dns_hostnames = true # Allows AWS internal hostnames

  database_subnet_group_name = "microservices-db-subnet-group"
}