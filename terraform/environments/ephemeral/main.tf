# ---------------------
# 1️⃣ יצירת EC2 + K3s
# ---------------------
module "k3s_cluster" {
  source        = "../../modules/k3s_cluster"
  aws_region    = var.aws_region
  env_name      = var.env_name
  instance_type = var.instance_type
  key_name      = var.key_name
  k3s_token     = var.k3s_token
  private_key_path = var.private_key_path
}
#
# resource "time_sleep" "wait_for_k3s" {
#   depends_on      = [module.k3s_cluster]
#   create_duration = "120s"
# }

# ---------------------
# 2️⃣ יצירת Secrets
# ---------------------
# resource "kubernetes_secret" "database_credentials" {
#   # depends_on = [module.k3s_cluster]
#   provider = kubernetes
#   metadata {
#     name      = "aws-secret"
#     namespace = "default"
#   }
#   data = {
#     username = "admin"
#     password = var.aws_pass
#   }
#   type       = "Opaque"
#   depends_on = [time_sleep.wait_for_k3s]
# }

# ---------------------
# 3️⃣ התקנת ArgoCD דרך Helm
# # ---------------------
# module "argocd_install" {
#   source       = "../../modules/argocd"
#   depends_on   = [time_sleep.wait_for_k3s,module.k3s_cluster]
#   # depends_on = []
#   k3s_node_id  = module.k3s_cluster.k3s_node_id
# }

# ---------------------
# 4️⃣ Outputs
# ---------------------
