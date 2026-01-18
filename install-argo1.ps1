# ============================================================
# Ultra-Secure GitOps Deployment Pipeline
# ============================================================
$ErrorActionPreference = "Stop"
$REPO_URL = "https://github.com/ronaelshef3/GitOps1.git"
$REMOTE_USER = "ubuntu"
$SSH_KEY = $env:SSH_PRIVATE_KEY_PATH

# Check SSH Key
if (-not $SSH_KEY -or -not (Test-Path $SSH_KEY)) {
    Write-Host "ERROR: SSH key not found!" -ForegroundColor Red
    Write-Host "Set: `$env:SSH_PRIVATE_KEY_PATH = 'C:\path\to\key.pem'" -ForegroundColor Yellow
    exit 1
}

Write-Host "SSH key found: $SSH_KEY" -ForegroundColor Green

# Cleanup handler
$cleanupNeeded = $false
trap {
    Write-Host "`nERROR: $($_.Exception.Message)" -ForegroundColor Red

    if ($cleanupNeeded) {
        Write-Host "Cleaning up..." -ForegroundColor Yellow
        try {
            Set-Location "$PSScriptRoot\terraform\environments\ephemeral"
            terraform destroy -auto-approve -lock=false
            Write-Host "Cleanup done" -ForegroundColor Green
        } catch {
            Write-Host "Manual cleanup needed!" -ForegroundColor Red
        }
    }

    Remove-Item "$env:TEMP\root.yaml" -Force -ErrorAction SilentlyContinue
    exit 1
}

# 1. Terraform
Write-Host "`n=== STEP 1: Terraform ===" -ForegroundColor Cyan
Set-Location "$PSScriptRoot\terraform\environments\ephemeral"

terraform init -upgrade
terraform apply -auto-approve

if ($LASTEXITCODE -ne 0) {
    Write-Host "Terraform failed!" -ForegroundColor Red
    exit 1
}

$cleanupNeeded = $true

$IP = terraform output -raw server_ip
if ([string]::IsNullOrWhiteSpace($IP) -or $IP -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
    Write-Host "Invalid IP: $IP" -ForegroundColor Red
    exit 1
}

Write-Host "Instance IP: $IP" -ForegroundColor Green
$REMOTE = "$REMOTE_USER@$IP"

# 2. Wait for SSH
Write-Host "`n=== STEP 2: Waiting for SSH ===" -ForegroundColor Cyan

$retries = 0
while ($retries -lt 30) {
    try {
        $result = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 $REMOTE "echo OK" 2>$null
        if ($result -eq "OK") {
            Write-Host "SSH ready!" -ForegroundColor Green
            break
        }
    } catch {}

    Write-Host "Waiting... ($($retries + 1)/30)" -ForegroundColor Yellow
    Start-Sleep 5
    $retries++
}

if ($retries -eq 30) {
    Write-Host "SSH timeout!" -ForegroundColor Red
    exit 1
}

# 3. System prep
Write-Host "`n=== STEP 3: System Prep ===" -ForegroundColor Cyan

$prepScript = @'
set -e
echo "Installing packages..."
sudo apt-get update -qq
sudo apt-get install -y apache2-utils >/dev/null 2>&1

echo "Swap..."
if ! swapon --show | grep -q swapfile; then
    sudo fallocate -l 4G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
fi

sudo sysctl -w vm.max_map_count=262144 >/dev/null

echo "Kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

echo "System ready"
'@

ssh -i $SSH_KEY -t -o StrictHostKeyChecking=accept-new $REMOTE $prepScript

if ($LASTEXITCODE -ne 0) {
    Write-Host "System prep failed!" -ForegroundColor Red
    exit 1
}

# 4. Generate password
Write-Host "`n=== STEP 4: Generate Password ===" -ForegroundColor Cyan

$passGen = @'
set -e
if ! openssl rand -base64 18 > ~/.argocd_admin_pass; then
    echo "Password generation failed!"
    exit 1
fi
chmod 600 ~/.argocd_admin_pass
if [ ! -s ~/.argocd_admin_pass ]; then
    echo "Password file empty!"
    exit 1
fi
echo "Password generated"
'@

ssh -i $SSH_KEY -t -o StrictHostKeyChecking=accept-new $REMOTE $passGen

if ($LASTEXITCODE -ne 0) {
    Write-Host "Password generation failed!" -ForegroundColor Red
    exit 1
}

# 5. Install ArgoCD
Write-Host "`n=== STEP 5: Install ArgoCD ===" -ForegroundColor Cyan

$argoInstall = @'
set -e
export KUBECONFIG=~/.kube/config

MY_PASS=$(cat ~/.argocd_admin_pass)
echo "Generating bcrypt..."
BCRYPT_PASS=$(htpasswd -bnBC 10 "" "$MY_PASS" | tr -d ':\n' | sed 's/:$//')

if [ -z "$BCRYPT_PASS" ]; then
    echo "Bcrypt failed!"
    exit 1
fi

if ! command -v helm &>/dev/null; then
    echo "Installing Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

echo "Helm repo..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update >/dev/null 2>&1

echo "Creating namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "Installing ArgoCD (5-10 min)..."
helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30007 \
  --set configs.secret.argocdServerAdminPassword="$BCRYPT_PASS" \
  --set controller.resources.limits.memory=600Mi \
  --wait \
  --timeout 10m

if [ $? -ne 0 ]; then
    echo "ArgoCD install failed!"
    exit 1
fi

echo "ArgoCD installed"
'@

ssh -i $SSH_KEY -t -o StrictHostKeyChecking=accept-new $REMOTE $argoInstall

if ($LASTEXITCODE -ne 0) {
    Write-Host "ArgoCD install failed!" -ForegroundColor Red
    exit 1
}

# 6. Wait for API
Write-Host "`n=== STEP 6: Wait for ArgoCD API ===" -ForegroundColor Cyan

$apiWait = @'
set -e
export KUBECONFIG=~/.kube/config
echo "Waiting for API..."
for i in {1..60}; do
    READY=$(kubectl -n argocd get deployment argocd-server -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$READY" -ge "1" ]; then
        echo "API ready"
        exit 0
    fi
    sleep 5
done
echo "Timeout!"
exit 1
'@

ssh -i $SSH_KEY -t -o StrictHostKeyChecking=accept-new $REMOTE $apiWait

if ($LASTEXITCODE -ne 0) {
    Write-Host "API timeout!" -ForegroundColor Red
    exit 1
}

# 7. Deploy root app
Write-Host "`n=== STEP 7: Deploy Root App ===" -ForegroundColor Cyan

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
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
"@

$tempFile = "$env:TEMP\root.yaml"
$manifest | Out-File -FilePath $tempFile -Encoding UTF8

Write-Host "Copying manifest..." -ForegroundColor Yellow
scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new $tempFile "${REMOTE}:/tmp/root.yaml"

if ($LASTEXITCODE -ne 0) {
    Write-Host "SCP failed!" -ForegroundColor Red
    exit 1
}

$applyScript = @'
set -e
export KUBECONFIG=~/.kube/config
if ! kubectl apply -f /tmp/root.yaml; then
    echo "kubectl apply failed!"
    exit 1
fi
echo "Root app deployed"
rm -f /tmp/root.yaml
'@

ssh -i $SSH_KEY -t -o StrictHostKeyChecking=accept-new $REMOTE $applyScript

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deploy failed!" -ForegroundColor Red
    exit 1
}

# 8. Get password & cleanup
Write-Host "`n=== STEP 8: Cleanup ===" -ForegroundColor Cyan

$rawPass = ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $REMOTE "cat ~/.argocd_admin_pass 2>/dev/null"

if ($rawPass -and $rawPass.Trim().Length -gt 0) {
    $FINAL_PASS = $rawPass.Trim()
    Write-Host "Password retrieved" -ForegroundColor Green
} else {
    Write-Host "Could not get password!" -ForegroundColor Yellow
    $FINAL_PASS = "[FAILED]"
}

ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new $REMOTE "rm -f ~/.argocd_admin_pass" 2>$null
Write-Host "Server password deleted" -ForegroundColor Green

Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
Write-Host "Local files cleaned" -ForegroundColor Green

# SUCCESS
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "    DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

Write-Host "`nAccess Info:" -ForegroundColor Cyan
Write-Host "  ArgoCD UI:  http://${IP}:30007" -ForegroundColor Yellow
Write-Host "  Username:   admin" -ForegroundColor Yellow
Write-Host "  Password:   $FINAL_PASS" -ForegroundColor Yellow
Write-Host "`n  App URL:    http://${IP}:30080" -ForegroundColor Yellow

Write-Host "`nSAVE THE PASSWORD - Server copy deleted!" -ForegroundColor Red

Start-Process "http://${IP}:30007"
Write-Host "`nBrowser opened. Happy GitOps!" -ForegroundColor Green