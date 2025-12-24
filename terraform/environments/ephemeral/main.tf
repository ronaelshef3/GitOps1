# 1. הקמת השרת (EC2 + K3s)
module "k3s_cluster" {
  source        = "../../modules/k3s_cluster"
  aws_region    = "us-east-1"
  env_name      = "ephemeral"
  instance_type = "t3.small"
}

# 2. התקנת ArgoCD (דרך Helm)
module "argocd_install" {
  source     = "../../modules/argocd"
  depends_on = [module.k3s_cluster]

  # אם המודול argocd מכיר את המשתנה host, שים אותו כאן בלי גרשיים:
  # host = module.k3s_cluster.public_ip
}
# 3. הדפסת ה-IP של השרת בסיום
output "server_ip" {
  value = module.k3s_cluster.public_ip
}