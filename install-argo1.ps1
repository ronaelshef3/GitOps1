# ============================================================
# GitOps Deployment Pipeline - Pure GitOps Mode
# ============================================================
$ErrorActionPreference = "Continue"
$REPO_URL = "https://github.com/ronaelshef3/GitOps1.git"
$REMOTE_USER = "ubuntu"
$SSH_KEY = $env:SSH_PRIVATE_KEY_PATH

Set-Location $PSScriptRoot

# 1. Terraform Apply
Write-Host "`n=== STEP 1: Terraform ===" -ForegroundColor Cyan
Set-Location "terrform1/environments/test"
terraform init -upgrade
terraform apply -auto-approve

$IP = (terraform output -raw server_ip).Trim()
Write-Host "Instance IP: $IP" -ForegroundColor Green
$REMOTE = "$REMOTE_USER@$IP"
Set-Location $PSScriptRoot

# 2. Waiting for SSH
Write-Host "`n=== STEP 2: Waiting for SSH ===" -ForegroundColor Cyan
$retries = 0
while ($retries -lt 30) {
    ssh -q -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 $REMOTE "echo OK" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SSH ready!" -ForegroundColor Green
        break
    }
    Write-Host "Waiting... ($($retries + 1)/30)" -ForegroundColor Yellow
    Start-Sleep 5
    $retries++
}

# 3. System Prep - Running external script
Write-Host "`n=== STEP 3: Running External System Prep ===" -ForegroundColor Cyan
# העלאה והרצה של הסקריפט הקיים בתיקיית השורש שלך
scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new "setup\system-prep.sh" "${REMOTE}:/tmp/system-prep.sh"
ssh -i $SSH_KEY -t $REMOTE "chmod +x /tmp/system-prep.sh && sudo /tmp/system-prep.sh"

# 4. Install ArgoCD - Running external script
Write-Host "`n=== STEP 4: Running External Argo Install ===" -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=accept-new "setup\install-argo.sh" "${REMOTE}:/tmp/install-argo.sh"
ssh -i $SSH_KEY -t $REMOTE "chmod +x /tmp/install-argo.sh && sudo /tmp/install-argo.sh"

# 5. Deploy Root App (REFERENCING GIT - No Hardcoded YAML)
Write-Host "`n=== STEP 5: Deploying Root App from Git Reference ===" -ForegroundColor Cyan
# במקום לייצר YAML, אנחנו פשוט אומרים לקיוב להחיל את הקובץ שקיים בתיקיית ה-bootstrap בגיט
# אנחנו משתמשים בנתיב ה-Raw של גיטהאב כדי שהשרת יוכל למשוך אותו ישירות
$ROOT_APP_URL = "https://raw.githubusercontent.com/ronaelshef3/GitOps1/master/bootstrap/root-app.yaml"

ssh -i $SSH_KEY -t $REMOTE "kubectl apply -f $ROOT_APP_URL"

# 6. Final Info
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "    DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "  ArgoCD UI: http://$IP:30007" -ForegroundColor Yellow
Write-Host "  Check ArgoCD for sync status of Root App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green

Start-Process "http://$IP:30007"

# 6. שליפת הסיסמה מהשרת (חובה לבצע לפני ההדפסה)
Write-Host "`n=== STEP 6: Retrieving ArgoCD Password ===" -ForegroundColor Cyan
$ARGO_PASS = ssh -i $SSH_KEY -q $REMOTE "sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"

# 7. הדפסה סופית עם המשתנים
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "    DEPLOYMENT SUCCESSFUL!" -ForegroundColor Green
Write-Host "  ArgoCD UI: http://${IP}:30007" -ForegroundColor Yellow
Write-Host "  Username:  admin" -ForegroundColor Yellow
Write-Host "  Password:  $ARGO_PASS" -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "  Check ArgoCD for sync status of Root App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Green

# פתיחה אוטומטית של הדפדפן
if ($IP) {
    Start-Process "http://${IP}:30007"
}