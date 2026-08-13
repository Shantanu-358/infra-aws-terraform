module "eks" {
    source = "terraform-aws-modules/eks/aws"
    version = "~> 19.0"

    cluster_name = "microservices-eks"
    cluster_version = "1.30"

    vpc_id      = module.vpc.vpc_id
    subnet_ids  = module.vpc.private_subnets

    cluster_endpoint_public_access = true

    # Enable IAM Roles for Service Accounts (IRSA)
    enable_irsa = true

    eks_managed_node_groups = {
        main = {
            min_size        = 2
            max_size        = 4
            desired_size    = 2

            instance_types  = ["t3.medium"]
            capacity_type   = "ON_DEMAND"
        }
    }

}