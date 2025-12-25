terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# הגדרת ה-Provider של קוברנטיס
provider "kubernetes" {
  host     = module.k3s_cluster.public_ip != "" ? "https://${module.k3s_cluster.public_ip}:6443" : "https://localhost"
  insecure = true
}

provider "helm" {
kubernetes= {
    host     = module.k3s_cluster.public_ip != "" ? "https://${module.k3s_cluster.public_ip}:6443" : ""
    insecure = true
    token = var.k3s_token
}
}