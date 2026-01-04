# output "argocd_initial_password" {
#   # value     = module.argocd_install.argocd_password
#   sensitive = true # נשים false כדי שתראה את זה ישר בטרמינל
# }
output "server_ip" {
  value = module.k3s_cluster.public_ip
}
# output "argocd_url" {
#   value       = "https://${module.k3s_cluster.public_ip}"
#   description = "The public IP of the K3s server where ArgoCD is running"
# }

output "ssh_command" {
  value       = "ssh -i ${var.private_key_path} ubuntu@${module.k3s_cluster.public_ip}"
  description = "Command to connect to the node"
}
