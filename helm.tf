# --------------------------------------------------------------------------------
# Configures Kubernetes and Helm providers using dynamic AWS EKS auth tokens
# --------------------------------------------------------------------------------
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

# --------------------------------------------------------------------------------
# 1. AWS Load Balancer Controller ServiceAccount & Helm Release
# --------------------------------------------------------------------------------
resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.load_balancer_controller_irsa_role.iam_role_arn
    }
    labels = {
      "app.kubernetes.io/component" = "controller"
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
    }
  }

  depends_on = [module.eks]
}

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
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.aws_load_balancer_controller.metadata[0].name
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
    module.eks,
    kubernetes_service_account.aws_load_balancer_controller,
    time_sleep.wait_for_alb_deletion
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
          namespace  = "argocd"
          finalizers = []
          project    = "default"
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
# 4. Microservices Dynamic Secrets (Helm Release)
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

# --------------------------------------------------------------------------------
# 5. Automated Database Initialization Job (Runs init.sql on RDS PostgreSQL)
# --------------------------------------------------------------------------------
resource "helm_release" "db_init" {
  name             = "db-init"
  chart            = "${path.module}/charts/db-init"
  namespace        = "microservices"
  create_namespace = true

  set {
    name  = "namespace"
    value = "microservices"
  }

  set {
    name  = "rdsHost"
    value = aws_db_instance.postgres.address
  }

  set {
    name  = "dbUser"
    value = aws_db_instance.postgres.username
  }

  set {
    name  = "dbPassword"
    value = var.db_password
  }

  set {
    name  = "dbName"
    value = aws_db_instance.postgres.db_name
  }

  depends_on = [
    module.eks,
    aws_db_instance.postgres,
    helm_release.argocd_application
  ]
}


# --------------------------------------------------------------------------------
# 6. Prometheus & Grafana Monitoring Stack (kube-prometheus-stack)
# --------------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  count            = var.enable_monitoring ? 1 : 0
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  version          = var.prometheus_helm_version
  create_namespace = true

  values = [
    yamlencode({
      # Grafana Configuration
      grafana = {
        enabled       = true
        adminPassword = var.grafana_admin_password
        service = {
          type = "ClusterIP"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "100Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      # Prometheus Server Configuration
      prometheus = {
        prometheusSpec = {
          retention                               = "12h"
          retentionSize                           = "3GiB"
          podMonitorSelectorNilUsesHelmValues     = false
          serviceMonitorSelectorNilUsesHelmValues = false
          ruleSelectorNilUsesHelmValues           = false
          resources = {
            requests = {
              cpu    = "100m"
              memory = "250Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "600Mi"
            }
          }
        }
      }

      # Alertmanager Configuration
      alertmanager = {
        alertmanagerSpec = {
          retention = "12h"
          resources = {
            requests = {
              cpu    = "20m"
              memory = "50Mi"
            }
            limits = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }
        }
      }

      # Node Exporter Configuration
      nodeExporter = {
        enabled = true
        resources = {
          requests = {
            cpu    = "20m"
            memory = "30Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "60Mi"
          }
        }
      }

      # Kube State Metrics Configuration
      kube-state-metrics = {
        resources = {
          requests = {
            cpu    = "20m"
            memory = "50Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "100Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    helm_release.argocd
  ]
}

# --------------------------------------------------------------------------------
# 7. Teardown Safety Buffer (Allows AWS ALB Controller to delete ALBs on Destroy)
# --------------------------------------------------------------------------------
resource "time_sleep" "wait_for_alb_deletion" {
  destroy_duration = "30s"

  depends_on = [
    helm_release.argocd_application
  ]
}
