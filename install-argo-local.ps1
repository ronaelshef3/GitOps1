# 1. יצירת Namespace
Write-Host "--- STEP 1: Creating Namespace ---" -ForegroundColor Cyan
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 2. התקנת ArgoCD
Write-Host "--- STEP 2: Installing ArgoCD ---" -ForegroundColor Cyan
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. המתנה שהשרת יעלה
Write-Host "--- STEP 3: Waiting for ArgoCD Server ---" -ForegroundColor Yellow
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# 4. שליפת סיסמה ופיענוח
Write-Host "--- STEP 4: Retrieving Credentials ---" -ForegroundColor Cyan
$pass_encoded = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'

if ($null -ne $pass_encoded -and $pass_encoded -ne "") {
    $pass_decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($pass_encoded))

    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  ArgoCD Local is Ready!"
    Write-Host "  URL:      https://localhost:8080"
    Write-Host "  Username: admin"
    Write-Host "  Password: $pass_decoded"
    Write-Host "========================================`n" -ForegroundColor Green
} else {
    Write-Host "Could not retrieve password. Try running the script again in a minute." -ForegroundColor Red
}

# 5. חור תולעת (Port-Forward)
Write-Host "--- STEP 5: Opening Wormhole (Port-Forward) ---" -ForegroundColor Cyan
Write-Host "Keep this window open!" -ForegroundColor DarkGray

# פתיחת דפדפן
Start-Process "https://localhost:8080"

# הפעלת הצינור
kubectl port-forward svc/argocd-server -n argocd 8080:443