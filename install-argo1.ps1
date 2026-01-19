# ============================================================
# Ultra-Secure GitOps Deployment Pipeline - REBASED
# ============================================================
$ErrorActionPreference = "Stop"
$REPO_URL = "https://github.com/ronaelshef3/GitOps1.git"
$REMOTE_USER = "ubuntu"
$SSH_KEY = $env:SSH_PRIVATE_KEY_PATH

# Check SSH Key
if (-not $SSH_KEY -or -not (Test-Path $SSH_KEY)) {
    Write-Host "ERROR: SSH key not found at $SSH_KEY" -ForegroundColor Red
    exit 1
}

$cleanupNeeded = $false
trap {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($cleanupNeeded) {
        Write-Host "Cleaning up Terraform..." -ForegroundColor Yellow
        Set-Location "$PSScriptRoot\terraform\environments\ephemeral"
        terraform destroy -auto-approve -lock=false
    }
    exit 1
}

# 1. Terraform Apply
Write-Host "`n=== STEP 1: Terraform ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot\terrform1\environments\test"
terraform init -upgrade
terraform apply -auto-approve
$cleanupNeeded = $true

$IP = (terraform output -raw server_ip).Trim()
Write-Host "Instance IP: $IP" -ForegroundColor Green
$REMOTE = "$REMOTE_USER@$IP"

# 2. Wait for SSH & K3s (Terraform handles installation)
Write-Host "`n=== STEP 2: Waiting for Cloud-Init & SSH ===" -ForegroundColor Cyan
$retries = 0
while ($retries -lt 30) {
    $check = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 $REMOTE "sudo kubectl get nodes" 2>$null
    if ($check -match "Ready") {
        Write-Host "K3s is Ready!" -ForegroundColor Green
        break
    }
    Write-Host "Waiting for K3s to be ready... ($($retries + 1)/30)" -ForegroundColor Yellow
    Start-Sleep 10
    $retries++
}

# 3. System Prep (Minor adjustments only)
Write-Host "`n=== STEP 3: OS Optimization ===" -ForegroundColor Cyan
$prepScript = @'
sudo sysctl -w vm.max_map_count=262144
if ! swapon --show | grep -q swapfile; then
    sudo fallocate -l 2G /swapfile && sudo chmod 600 /swapfile
    sudo mkswap /swapfile && sudo swapon /swapfile
fi
# Ensure kubeconfig is available for current user
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
'@
ssh -i $SSH_KEY -t $REMOTE $prepScript

# 4. Install ArgoCD (Using the port 30007 we opened)
Write-Host "`n=== STEP 4: Install ArgoCD ===" -ForegroundColor Cyan
# Generate a random password locally to pass it safely
$ADMIN_PASS = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | % {[char]$_})

$argoInstall = @"
set -e
export KUBECONFIG=~/.kube/config
if ! command -v helm &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
helm repo add argo https://argoproj.github.io/argo-helm --force-update
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install argocd argo/argo-cd -n argocd \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30007 \
  --set configs.secret.argocdServerAdminPassword=\$(htpasswd -bnBC 10 "" "$ADMIN_PASS" | tr -d ':\n') \
  --wait --timeout 10m
"@
ssh -i $SSH_KEY -t $REMOTE $argoInstall

# 5. Deploy Root App
Write-Host "`n=== STEP 5: Deploy Root App ===" -ForegroundColor Cyan
$manifest = @"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO_URL
    path: bootstrap
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated: {prune: true, selfHeal: true}
"@
$manifest | ssh -i $SSH_KEY $REMOTE "cat > /tmp/root.yaml && kubectl apply -f /tmp/root.yaml"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "    DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "  URL: http://$IP:30007" -ForegroundColor Yellow
Write-Host "  User: admin / Pass: $ADMIN_PASS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Green

Start-Process "http://$IP:30007"