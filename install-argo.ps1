# 1. Infrastructure Deployment
cd .\terraform\environments\ephemeral\
terraform init
terraform apply -auto-approve

# 2. Extract Public IP
$InstanceIP = terraform output -raw server_ip
if ([string]::IsNullOrWhiteSpace($InstanceIP) -or $InstanceIP -match "No outputs"){
    Write-Host "Error: Cannot retrieve IP from Terraform." -ForegroundColor Red
    exit
}
Write-Host "Target IP: $InstanceIP"

# 3. Define Connectivity Variables
$SSH_KEY = "C:\Users\USER\Downloads\MY_KEY.pem"
$REMOTE_USER = "ubuntu"
$REMOTE_TARGET = "${REMOTE_USER}@${InstanceIP}"
$REPO_URL = "https://github.com/ronaelshef3/GitOps1.git"

# 4. Resource Health Check (Stop if > 90%)
Write-Host "Checking server resources..." -ForegroundColor Yellow
$mem_usage = & ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET "free | grep Mem | awk '{print int(\$3/\$2 * 100)}'"
if ([int]$mem_usage -gt 90) {
    Write-Host "FATAL ERROR: Memory usage is at $mem_usage%. Instance is overloaded! Stopping." -ForegroundColor Red
    exit
}
Write-Host "Memory usage is safe: $mem_usage%" -ForegroundColor Green

# 5. OS Optimization for Heavy Apps (Prometheus/Grafana)
Write-Host "Creating 4GB SWAP and tuning kernel parameters..." -ForegroundColor Yellow
$os_tune = "sudo swapoff -a; sudo fallocate -l 4G /swapfile; sudo chmod 600 /swapfile; sudo mkswap /swapfile; sudo swapon /swapfile; " +
           "sudo sysctl -w vm.max_map_count=262144"
& ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET $os_tune

# 6. Wait for K3s
Write-Host "Waiting for K3s to be ready..." -ForegroundColor Yellow
$k3s_ready = $false
while (-not $k3s_ready) {
    $check = & ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET "sudo /usr/local/bin/k3s kubectl get nodes" 2>$null
    if ($check -match "Ready") { $k3s_ready = $true }
    else { Write-Host "." -NoNewline; Start-Sleep -Seconds 10 }
}
Write-Host "`nK3s is up!" -ForegroundColor Green

# 7. Install Helm & ArgoCD via Helm (High Capacity Config)
Write-Host "Installing ArgoCD via Helm with high resource limits..." -ForegroundColor Yellow
$helm_install = "if ! command -v helm &> /dev/null; then curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; fi; " +
               "sudo /usr/local/bin/k3s kubectl create namespace argocd; " +
               "sudo helm repo add argo https://argoproj.github.io/argo-helm; " +
               "sudo helm repo update; " +
               "sudo helm install argocd argo/argo-cd -n argocd " +
               "--set controller.resources.limits.memory=1024Mi " +
               "--set server.resources.limits.memory=512Mi " +
               "--set repoServer.resources.limits.memory=512Mi " +
               "--set server.service.type=NodePort --set server.service.nodePortHttp=30007 " +
               "--kubeconfig /etc/rancher/k3s/k3s.yaml"
& ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET $helm_install

# 8. Wait for ArgoCD Pods (Visual Status)
Write-Host "Waiting for ArgoCD Pods to stabilize..." -ForegroundColor Yellow
$argo_ready = $false
while (-not $argo_ready) {
    $status = & ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET "sudo /usr/local/bin/k3s kubectl get pods -n argocd --no-headers" 2>$null
    if ($status -match "Running" -and -not ($status -match "Pending|ContainerCreating")) {
        $argo_ready = $true
        Write-Host "`nArgoCD Pods are Ready!" -ForegroundColor Green
    } else {
        Write-Host "." -NoNewline -ForegroundColor Cyan
        Start-Sleep -Seconds 10
    }
}

# 9. Retrieve Password & CLI Login
$pass_query = "sudo /usr/local/bin/k3s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'"
$encoded_pass = & ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET $pass_query
$decoded_pass = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encoded_pass))

& ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET "sudo pkill -f port-forward; sudo nohup /usr/local/bin/k3s kubectl port-forward svc/argocd-server -n argocd 8080:443 --address 0.0.0.0 > pf.log 2>&1 &"
Start-Sleep -Seconds 10
& ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET "sudo /usr/local/bin/argocd login localhost:8080 --username admin --password $decoded_pass --insecure"

# 10. Create Root Application (Git Reference Mode)
Write-Host "Deploying Root Application from $REPO_URL..." -ForegroundColor Yellow
$app_cmd = "sudo /usr/local/bin/argocd app create root-app " +
           "--repo $REPO_URL --path bootstrap " +
           "--dest-server https://kubernetes.default.svc --dest-namespace default " +
           "--sync-policy automated --server localhost:8080 --insecure"
& ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET $app_cmd

# 11. Final Sync & Open Browser
Write-Host "Final Syncing..." -ForegroundColor Green
& ssh -i $SSH_KEY -o StrictHostKeyChecking=no $REMOTE_TARGET "sudo /usr/local/bin/argocd app sync root-app --server localhost:8080 --insecure"

$URL = "http://$($InstanceIP):30007"
Write-Host "Deployment Successful! Access ArgoCD UI: $URL" -ForegroundColor Cyan
Start-Process $URL