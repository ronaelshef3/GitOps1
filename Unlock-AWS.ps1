# Unlock-Vault.ps1
# Retrieves secret, validates environment, and tests AWS connectivity.

$TargetName = "AWS_SECRET_ACCESS_KEY"

# 1. Pull the Secret Key from Windows Vault
$cred = Get-StoredCredential -Target $TargetName

if ($cred) {
    $env:AWS_SECRET_ACCESS_KEY = $cred.Password
    Write-Host "[1/3] Secret Key loaded to memory." -ForegroundColor Green
} else {
    Write-Host "[!] Error: $TargetName not found in Vault." -ForegroundColor Red ; return
}

# 2. Check if the Public Access Key exists (the one you set as System variable)
if ($env:AWS_ACCESS_KEY_ID) {
    Write-Host "[2/3] Public Access Key detected: $env:AWS_ACCESS_KEY_ID" -ForegroundColor Green
} else {
    Write-Host "[!] Error: AWS_ACCESS_KEY_ID is missing from System variables." -ForegroundColor Red ; return
}

# 3. DIRECT CALL TO AWS: Verify the handshake works
Write-Host "[3/3] Testing AWS connection..." -ForegroundColor Cyan

# This is the actual call to AWS API
$awsTest = aws sts get-caller-identity 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "----------------------------------------------" -ForegroundColor Yellow
    Write-Host "SUCCESS: Vault Unlocked and AWS Verified!" -ForegroundColor Green
    Write-Host "----------------------------------------------" -ForegroundColor Yellow
} else {
    Write-Host "[!] AWS Handshake Failed. Check your keys or internet." -ForegroundColor Red
}