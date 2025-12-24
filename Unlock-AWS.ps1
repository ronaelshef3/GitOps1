# Unlock-Vault.ps1
$TargetName = "AWS_SECRET_ACCESS_KEY"

# Check if the key exists in Windows Vault
$vaultCheck = cmdkey /list | Select-String $TargetName

if ($vaultCheck) {
    # Extract the password using cmdkey
    $rawOutput = cmdkey /get:$TargetName
    $passwordLine = $rawOutput | Select-String "Password:"

    if ($passwordLine) {
        $secret = ($passwordLine.ToString().Split(":", 2)[1]).Trim()

        # Inject to current session RAM only
        $env:AWS_SECRET_ACCESS_KEY = $secret

        Write-Host "--- SUCCESS: Secret Key Injected from Vault ---" -ForegroundColor Green
        aws sts get-caller-identity
    }
} else {
    Write-Host "--- ERROR: Key not found in Credential Manager ---" -ForegroundColor Red
}