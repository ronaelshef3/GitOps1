terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# AWS Provider
provider "aws" {
  region = var.aws_region
}

# Kubernetes Providers
provider "kubernetes" {
  alias                  = "bootstrap"
  host                   = "https://${module.k3s_cluster.public_ip}:6443"
  cluster_ca_certificate = base64decode(var.k3s_ca_cert)
  client_certificate     = base64decode(var.k3s_client_cert)
  client_key             = base64decode(var.k3s_client_key)
  # depends_on = [module.k3s_cluster]

}

provider "kubernetes" {
  alias    = "main"
  host     = "https://${module.k3s_cluster.public_ip}:6443"
  token    = var.k3s_token
  insecure = true
  # depends_on = [module.k3s_cluster]

}

# Helm Provider
provider "helm" {
  kubernetes {
    host     = "https://${module.k3s_cluster.public_ip}:6443"
    token    = var.k3s_token
    insecure = true
    # depends_on = [module.k3s_cluster]

  }
}
