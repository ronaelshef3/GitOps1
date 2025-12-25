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