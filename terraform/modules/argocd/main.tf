resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  depends_on = [var.k3s_node_id]

 values = [
    yamlencode({
      server = {
        service = {
          type     = "NodePort"
          nodePort = 30007
        }
      }
    })
  ]
}
data "kubernetes_secret" "argocd_admin_password" {
  depends_on = [helm_release.argocd]
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
}