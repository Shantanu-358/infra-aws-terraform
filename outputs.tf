output "vpc_id" {
  description = "The ID of the custom Virtual Private Cloud"
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "The public endpoint URL for connecting to the EKS Kubernetes API"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "The name of the provisioned EKS cluster"
  value       = module.eks.cluster_name
}

output "rds_endpoint" {
  description = "The database connection hostname and port for PostgreSQL"
  value       = aws_db_instance.postgres.endpoint
}