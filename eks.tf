module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "microservices-eks"
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets
  control_plane_subnet_ids = module.vpc.public_subnets

  # Enable IAM Roles for Service Accounts (IRSA)
  enable_irsa = true

  # Grants cluster admin permissions to current Terraform caller identity
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.micro"]
      capacity_type  = "ON_DEMAND"

      # CRITICAL: Nodes in public subnets must receive public IPs to communicate without NAT Gateways
      associate_public_ip_address = true
      subnet_ids                  = module.vpc.public_subnets
    }
  }
}