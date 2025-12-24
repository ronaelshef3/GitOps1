# Setup-AWS.ps1 - Initial Configuration
Write-Host "--- AWS Identity & Vault Setup ---" -ForegroundColor Cyan

# 1. Get the Public Access Key ID
$PublicID = Read-Host "Enter your AWS Access Key ID (The public one)"

if ($PublicID) {
    [Environment]::SetEnvironmentVariable("AWS_ACCESS_KEY_ID", $PublicID, "User")
    $env:AWS_ACCESS_KEY_ID = $PublicID
    Write-Host "[OK] Public ID saved to Environment Variables." -ForegroundColor Green
}

# 2. Get the Secret Access Key securely (Password box style)
$Secret = Read-Host "Enter your AWS Secret Access Key" -AsSecureString

if ($Secret) {
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Save to Windows Credential Manager
    cmdkey /add:AWS_SECRET_ACCESS_KEY /user:aws-user /pass:$PlainPassword

    # Cleanup memory
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    Remove-Variable Secret, PlainPassword

    Write-Host "[OK] Secret Key locked in Windows Vault." -ForegroundColor Green
}

Write-Host "`nSetup Complete! Restart your terminal/PyCharm to apply changes." -ForegroundColor Yellow