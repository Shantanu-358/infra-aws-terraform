# --------------------------------------------------------------------------------
# EKS Cluster Data Sources (Deferred Evaluation for Helm Provider)
# --------------------------------------------------------------------------------
data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# --------------------------------------------------------------------------------
# 1. AWS Load Balancer Controller (Helm Release with Native ServiceAccount)
# --------------------------------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.alb_controller_helm_version

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.load_balancer_controller_irsa_role.iam_role_arn
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  depends_on = [
    module.eks
  ]
}

# --------------------------------------------------------------------------------
# 2. ArgoCD Installation via Helm
# --------------------------------------------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = var.argocd_helm_version
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  depends_on = [
    module.eks
  ]
}

# --------------------------------------------------------------------------------
# 3. ArgoCD Application Resource (Syncs GitOps Manifests Repo)
# --------------------------------------------------------------------------------
resource "helm_release" "argocd_application" {
  name       = "microservices-argo"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  namespace  = "argocd"
  version    = "2.0.2"

  values = [
    yamlencode({
      applications = {
        microservices-argo = {
          namespace = "argocd"
          finalizers = [
            "resources-finalizer.argocd.argoproj.io"
          ]
          project = "default"
          source = {
            repoURL        = var.gitops_repo_url
            targetRevision = "HEAD"
            path           = "."
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "microservices"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = [
              "CreateNamespace=true"
            ]
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.argocd
  ]
}

# --------------------------------------------------------------------------------
# 4. Microservices Dynamic Application Secrets (Helm Release via Local Chart)
# --------------------------------------------------------------------------------
resource "helm_release" "app_secrets" {
  name             = "app-secrets"
  chart            = "${path.module}/charts/app-secrets"
  namespace        = "microservices"
  create_namespace = true

  set {
    name  = "namespace"
    value = "microservices"
  }

  set {
    name  = "databaseUrl"
    value = "postgresql://dbadmin:${var.db_password}@${aws_db_instance.postgres.endpoint}/appdb"
  }

  set {
    name  = "jwtSecretKey"
    value = var.jwt_secret_key
  }

  depends_on = [
    module.eks,
    aws_db_instance.postgres,
    helm_release.argocd_application
  ]
}
