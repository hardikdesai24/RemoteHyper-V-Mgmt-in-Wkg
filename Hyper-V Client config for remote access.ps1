# Hyper-V Client Configuration Script for Remote Management in a Workgroup
# Run this script on the machine with Hyper-V Manager that will connect to remote Hyper-V hosts

param(
    [string]$HyperVHost = "*"  # Default to all hosts, or specify FQDN/IP
)

Write-Host "=== Hyper-V Client Configuration for Remote Management ===" -ForegroundColor Green
Write-Host "Target Host: $HyperVHost" -ForegroundColor Cyan
Write-Host ""

# 1. Configure WSMan TrustedHosts
Write-Host "1. Configuring WSMan TrustedHosts..." -ForegroundColor Yellow
try {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $HyperVHost -Force
    Write-Host "   ✓ TrustedHosts set to: $HyperVHost" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to set TrustedHosts: $_" -ForegroundColor Red
}

# 2. Enable CredSSP Client Role
Write-Host "2. Enabling CredSSP Client..." -ForegroundColor Yellow
try {
    Enable-WSManCredSSP -Role Client -DelegateComputer $HyperVHost -Force
    Write-Host "   ✓ CredSSP Client enabled for: $HyperVHost" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to enable CredSSP Client: $_" -ForegroundColor Red
}

# 3. Display Group Policy configuration instructions
Write-Host ""
Write-Host "=== Manual Configuration Required ===" -ForegroundColor Yellow
Write-Host "You must configure credential delegation policy manually:" -ForegroundColor White
Write-Host ""
Write-Host "Option 1 - Using Group Policy Editor (gpedit.msc):" -ForegroundColor Cyan
Write-Host "1. Run 'gpedit.msc' as Administrator" -ForegroundColor White
Write-Host "2. Navigate to: Computer Configuration > Administrative Templates > System > Credentials Delegation" -ForegroundColor White
Write-Host "3. Enable 'Allow delegating fresh credentials with NTLM-only server authentication'" -ForegroundColor White
Write-Host "4. Add 'wsman/*' or 'wsman/$HyperVHost' to the server list" -ForegroundColor White
Write-Host ""
Write-Host "Option 2 - Using Registry (if gpedit.msc not available):" -ForegroundColor Cyan
Write-Host "Run the following commands as Administrator:" -ForegroundColor White
Write-Host "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation`" /v AllowFreshCredentialsWhenNTLMOnly /t REG_DWORD /d 1 /f" -ForegroundColor Gray
Write-Host "reg add `"HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly`" /v 1 /t REG_SZ /d `"wsman/*`" /f" -ForegroundColor Gray
Write-Host ""

# 4. Display connection instructions
Write-Host "=== Connection Instructions ===" -ForegroundColor Green
Write-Host "After completing the credential delegation configuration:" -ForegroundColor White
Write-Host "1. Open Hyper-V Manager" -ForegroundColor White
Write-Host "2. Right-click 'Hyper-V Manager' and select 'Connect to Server...'" -ForegroundColor White
Write-Host "3. Choose 'Another computer' and enter: $HyperVHost" -ForegroundColor White
Write-Host "4. Provide credentials for a user in the 'Hyper-V Administrators' group" -ForegroundColor White
Write-Host ""
Write-Host "Note: A restart may be required for Group Policy changes to take effect." -ForegroundColor Yellow
Write-Host "Note: Use FQDN where possible for better reliability." -ForegroundColor Yellow
