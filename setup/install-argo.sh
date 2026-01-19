#!/bin/bash
set -e

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd -n argocd \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30007 \
  --set server.insecure=true

kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s