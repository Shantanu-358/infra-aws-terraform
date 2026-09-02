variable "aws_region" {
  description = "The primary AWS Region to deploy all infrastructure into"
  type        = string
  default     = "ap-south-2"
}

variable "environment" {
  description = "Deployment environment name (e.g. dev, staging, production)"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name for the Amazon EKS cluster"
  type        = string
  default     = "microservices-eks"
}

variable "db_password" {
  description = "Master password for the PostgreSQL RDS Database"
  type        = string
  sensitive   = true # Prevents Terraform from printing this password in CLI logs
  default     = "SecurePassword2026!"
}

variable "gitops_repo_url" {
  description = "GitOps repository URL containing Kubernetes manifests for ArgoCD to sync"
  type        = string
  default     = "https://github.com/Shantanu-358/gitops-manifests.git"
}

variable "jwt_secret_key" {
  description = "JWT Secret Key used by backend API for token signing"
  type        = string
  sensitive   = true
  default     = "c865f35c1f0aa4c5645f01f3f3ef72d0b589de88815b04f532748edaf26e799f"
}

variable "argocd_helm_version" {
  description = "Version of the ArgoCD Helm chart to install"
  type        = string
  default     = "7.3.11"
}

variable "alb_controller_helm_version" {
  description = "Version of the AWS Load Balancer Controller Helm chart to install"
  type        = string
  default     = "1.8.1"
}

variable "enable_deletion_protection" {
  description = "Enables deletion protection on RDS PostgreSQL database instance"
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Skip final RDS snapshot creation during terraform destroy"
  type        = bool
  default     = true
}

variable "prometheus_helm_version" {
  description = "Version of the kube-prometheus-stack Helm chart to install"
  type        = string
  default     = "69.3.0"
}

variable "grafana_admin_password" {
  description = "Administrator password for Grafana web UI"
  type        = string
  sensitive   = true
  default     = "PromGrafanaAdmin2026!"
}

variable "enable_monitoring" {
  description = "Toggle to enable or disable Prometheus & Grafana monitoring stack"
  type        = bool
  default     = true
}
