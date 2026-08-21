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

output "configure_kubectl_command" {
  description = "CLI Command to update local kubeconfig for kubectl access"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "argocd_admin_password_command" {
  description = "CLI Command to retrieve initial ArgoCD admin password"
  value       = "kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 --decode && echo"
}

output "get_ingress_url_command" {
  description = "CLI Command to fetch the live AWS ALB Ingress public endpoint URL"
  value       = "kubectl get ingress app-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' && echo"
}