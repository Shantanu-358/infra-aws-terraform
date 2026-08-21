module "vpc" {
  #checkov:skip=CKV_TF_1: "Using official AWS Terraform Registry module with version constraint"
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "microservices-free-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["ap-south-2a", "ap-south-2b"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  database_subnets = ["10.0.21.0/24", "10.0.22.0/24"]

  # Free Tier adjustments: No NAT Gateway
  enable_nat_gateway = false
  enable_vpn_gateway = false

  # CRITICAL FIX: Automatically assigns public IPs to instances launched in public subnets
  map_public_ip_on_launch = true

  # FIXED: Creates dedicated route tables for database subnets
  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  enable_dns_hostnames               = true
  enable_dns_support                 = true

  # Tags required by Kubernetes Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}