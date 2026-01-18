# ============================================================
# GitOps Automation Suite - Full Deployment Script
# ============================================================
param([switch]$Force)

# 0. ניקוי משתני סביבה כדי למנוע התנגשויות (פותר את בעיית ה-Partial Credentials)
$env:AWS_ACCESS_KEY_ID = $null
$env:AWS_SECRET_ACCESS_KEY = $null
$env:AWS_SESSION_TOKEN = $null

$ErrorActionPreference = "Continue" # מאפשר לנו לנהל שגיאות ידנית דרך Exit Codes
$SSH_KEY = $env:SSH_PRIVATE_KEY_PATH
$LOG_FILE = "$PSScriptRoot\deployment_log.txt"
$OUTPUT_JSON = "$PSScriptRoot\outputs.json"

function Write-Log($msg, $color = "White") {
    $timestamp = Get-Date -Format "HH:mm:ss"
    "[$timestamp] $msg" | Out-File $LOG_FILE -Append
    Write-Host "[$timestamp] $msg" -ForegroundColor $color
}

# וידוא קיום מפתח SSH
if (-not $SSH_KEY) {
    Write-Log "❌ Error: SSH_PRIVATE_KEY_PATH is empty! Please set it in Env Variables." "Red"
    exit 1
}

"--- New Deployment Session: $(Get-Date) ---" | Out-File $LOG_FILE

# 1. בדיקת שרת קיים בצורה בטוחה (ללא קריסה על Null)
Write-Log "Step 1: Checking for existing server via AWS CLI..." "Cyan"
$rawIp = aws ec2 describe-instances `
    --filters "Name=tag:Name,Values=ephemeral" "Name=instance-state-name,Values=running" `
    --query "Reservations[*].Instances[*].PublicIpAddress" `
    --output text 2>$null

$IP = $null
if ($null -ne $rawIp -and $rawIp.Trim().Length -gt 0 -and $rawIp -notmatch "None") {
    $IP = $rawIp.Trim()
    Write-Log "Found active server: $IP" "Green"
}

# 2. הרצת Terraform (רק אם השרת לא קיים או אם הופעל -Force)
if (-not $IP -or $Force) {
    Write-Log "Step 2: Starting Infrastructure Provisioning (Terraform)..." "Yellow"
    Set-Location "$PSScriptRoot\terraform\environments\ephemeral"
    terraform apply -auto-approve | Tee-Object -FilePath $LOG_FILE -Append

    $IP = (terraform output -raw server_ip).Trim()
    if ($null -eq $IP -or $IP -match "No outputs") {
        Write-Log "❌ Error: Terraform failed to provide an IP address." "Red"
        exit 1
    }
    Set-Location $PSScriptRoot
}

$REMOTE = "ubuntu@$IP"

# 3. בדיקת חיבור SSH (מבוסס Exit Code - מתעלם מאזהרות)
Write-Log "Step 3: Testing SSH connection to $IP..." "Cyan"
$connected = $false
for ($i=1; $i -le 12; $i++) {
    # 2>$null משתיק את אזהרת ה-Permanently Added
    ssh -i "$SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new $REMOTE "echo connection_ok" 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        $connected = $true
        Write-Log "SSH Connection established." "Green"
        break
    }
    Write-Log "Waiting for SSH (Try $i/12)..." "Yellow"
    Start-Sleep -Seconds 10
}

if (-not $connected) {
    Write-Log "❌ Fatal Error: SSH connection failed after 12 attempts." "Red"
    exit 1
}

# 4. העברת קבצים והתקנה
Write-Log "Step 4: Transferring Setup Scripts via SCP..." "Cyan"
$setupPath = Join-Path $PSScriptRoot "setup"

scp -i "$SSH_KEY" -r "$setupPath" "${REMOTE}:/tmp/"
if ($LASTEXITCODE -ne 0) {
    Write-Log "❌ Fatal Error: SCP transfer failed!" "Red"
    exit 1
}

Write-Log "Step 5: Running Remote Installation Scripts (Bash)..." "Cyan"
ssh -i "$SSH_KEY" -t $REMOTE "bash /tmp/setup/system-prep.sh && bash /tmp/setup/install-argo.sh"
if ($LASTEXITCODE -ne 0) {
    Write-Log "❌ Fatal Error: Remote scripts failed to execute!" "Red"
    exit 1
}

# 6. משיכת סיסמת ה-Admin הראשונית של ArgoCD
Write-Log "Step 6: Retrieving ArgoCD initial admin password..." "Cyan"
$PASS = (ssh -i "$SSH_KEY" $REMOTE "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d").Trim()

# שמירה והצגה סופית
$finalOutputs = @{
    IP        = $IP
    URL       = "http://$IP:30007"
    Username  = "admin"
    Password  = $PASS
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}
$finalOutputs | ConvertTo-Json | Out-File $OUTPUT_JSON

Write-Log "`n========================================" "Green"
Write-Log "  DEPLOYMENT SUCCESSFUL 🚀" "Green"
Write-Log "  URL:      http://$IP:30007" "Yellow"
Write-Log "  Username: admin"
Write-Log "  Password: $PASS" "Yellow"
Write-Log "  Logs:     $LOG_FILE" "Gray"
Write-Log "========================================`n"

# פתיחת דפדפן
Start-Process "http://$IP:30007"