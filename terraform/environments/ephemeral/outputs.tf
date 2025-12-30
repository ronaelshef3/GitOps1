output "argocd_initial_password" {
  value     = module.argocd_install.argocd_password
  sensitive = false # נשים false כדי שתראה את זה ישר בטרמינל
}
output "server_ip" {
  value = module.k3s_cluster.public_ip
}
