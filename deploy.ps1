param([switch]$Local, [switch]$Force)

$ErrorActionPreference = "Continue"
$SSH_KEY = $env:SSH_PRIVATE_KEY_PATH
$LOG_FILE = "$PSScriptRoot\deployment_log.txt"

function Write-Log($msg, $color = "White") {
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $msg" -ForegroundColor $color
    "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $LOG_FILE -Append
}

# --- 1. זיהוי סביבה ---
if ($Local) {
    Write-Log "MODE: LOCAL DOCKER" "Magenta"
    if (-not (docker ps -q -f name=debug-server)) {
        Write-Log "Building and starting Docker..." "Yellow"
        docker-compose up -d --build
        Start-Sleep -Seconds 5
    }
    $IP = "127.0.0.1"; $PORT = "2222"
    # הזרקת מפתח SSH לדוקר
    $pubKey = Get-Content "$SSH_KEY.pub"
    docker exec -i debug-server bash -c "echo '$pubKey' >> /home/ubuntu/.ssh/authorized_keys"
} else {
    Write-Log "MODE: AWS CLOUD" "Cyan"
    $IP = (aws ec2 describe-instances --filters "Name=tag:Name,Values=K3s-*" "Name=instance-state-name,Values=running" --query "Reservations[*].Instances[*].PublicIpAddress" --output text).Trim()
    if (-not $IP -or $Force) {
        Write-Log "Provisioning AWS with Terraform..." "Yellow"
        Set-Location "$PSScriptRoot\terraform\environments\ephemeral"
        terraform apply -auto-approve
        $IP = (terraform output -raw server_ip).Trim()
        Set-Location $PSScriptRoot
    }
    $PORT = "22"
}

# --- 2. הרצת התקנות ---
$sshOpts = "-i `"$SSH_KEY`" -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
$REMOTE = "ubuntu@$IP"

Write-Log "Transferring setup to $REMOTE..." "Cyan"
scp -P $PORT -i "$SSH_KEY" -o StrictHostKeyChecking=no -r "./setup" "${REMOTE}:/tmp/"

Write-Log "Executing system-prep and install-argo..." "Yellow"
ssh $sshOpts -t $REMOTE "bash /tmp/setup/system-prep.sh && bash /tmp/setup/install-argo.sh"

# --- 3. סיום ---
$PASS = (ssh $sshOpts $REMOTE "sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d").Trim()
Write-Log "DONE! URL: http://$IP:30007" "Green"
Write-Log "Admin Password: $PASS" "Green"
Start-Process "http://$IP:30007"