#!/bin/bash
set -e
export KUBECONFIG=~/.kube/config

echo "--- Installing ArgoCD ---"
# התקנת Helm אם חסר
if ! command -v helm &> /dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# יצירת סיסמה אקראית רק אם היא לא קיימת כבר
if [ ! -f ~/.argocd_admin_pass ]; then
    openssl rand -base64 15 | tr -dc 'a-zA-Z0-9' | head -c 12 > ~/.argocd_admin_pass
    chmod 600 ~/.argocd_admin_pass
fi

PASS=$(cat ~/.argocd_admin_pass)
# יצירת Bcrypt Hash עבור ארגו
sudo apt-get update -qq && sudo apt-get install -y apache2-utils > /dev/null
BCRYPT_PASS=$(htpasswd -bnBC 10 "" "$PASS" | tr -d ':\n' | sed 's/:\$//')

# התקנה עם Helm
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd -n argocd \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30007 \
  --set configs.secret.argocdServerAdminPassword="$BCRYPT_PASS" \
  --wait --timeout 10m

echo "✓ ArgoCD Installed Successfully"