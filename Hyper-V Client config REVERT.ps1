# Hyper-V Client Configuration Revert Script
# This script reverts the changes made by "Hyper-V Client config for remote access.ps1"

param(
    [switch]$KeepCredSSP = $false  # Option to keep CredSSP enabled for other uses
)

Write-Host "=== Reverting Hyper-V Client Configuration ===" -ForegroundColor Red
Write-Host "This will disable remote management capabilities configured for Hyper-V access." -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Are you sure you want to proceed? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""

# 1. Clear WSMan TrustedHosts
Write-Host "1. Clearing WSMan TrustedHosts..." -ForegroundColor Yellow
try {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "" -Force
    Write-Host "   ✓ TrustedHosts cleared" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to clear TrustedHosts: $_" -ForegroundColor Red
}

# 2. Disable CredSSP Client Role (optional)
if (-not $KeepCredSSP) {
    Write-Host "2. Disabling CredSSP Client..." -ForegroundColor Yellow
    try {
        Disable-WSManCredSSP -Role Client
        Write-Host "   ✓ CredSSP Client disabled" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to disable CredSSP Client: $_" -ForegroundColor Red
    }
} else {
    Write-Host "2. Keeping CredSSP Client enabled (as requested)..." -ForegroundColor Gray
}

# 3. Remove credential delegation policy
Write-Host "3. Removing credential delegation policy..." -ForegroundColor Yellow
$removePolicy = Read-Host "Remove credential delegation registry settings? This affects ALL CredSSP delegation (y/N)"
if ($removePolicy -eq 'y' -or $removePolicy -eq 'Y') {
    try {
        $credDelegationPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
        
        # Remove the delegation entries
        Remove-ItemProperty -Path "$credDelegationPath\AllowFreshCredentialsWhenNTLMOnly" -Name "1" -ErrorAction SilentlyContinue
        Remove-ItemProperty -Path $credDelegationPath -Name "AllowFreshCredentialsWhenNTLMOnly" -ErrorAction SilentlyContinue
        
        # Remove the subkeys if they're empty
        $subKey = "$credDelegationPath\AllowFreshCredentialsWhenNTLMOnly"
        if (Test-Path $subKey) {
            $items = Get-ItemProperty $subKey -ErrorAction SilentlyContinue
            if (-not $items -or ($items.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" }).Count -eq 0) {
                Remove-Item $subKey -Force -ErrorAction SilentlyContinue
            }
        }
        
        Write-Host "   ✓ Credential delegation policy removed" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to remove credential delegation policy: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   - Credential delegation policy left unchanged" -ForegroundColor Gray
}

# 4. Display manual cleanup instructions
Write-Host ""
Write-Host "=== Manual Cleanup Instructions ===" -ForegroundColor Yellow
Write-Host "The following may require manual cleanup:" -ForegroundColor White
Write-Host ""
Write-Host "• Group Policy Settings (if configured via gpedit.msc):" -ForegroundColor Cyan
Write-Host "  1. Run 'gpedit.msc' as Administrator" -ForegroundColor White
Write-Host "  2. Navigate to: Computer Configuration > Administrative Templates > System > Credentials Delegation" -ForegroundColor White
Write-Host "  3. Disable 'Allow delegating fresh credentials with NTLM-only server authentication'" -ForegroundColor White
Write-Host "  4. Remove any 'wsman/*' entries from the server list" -ForegroundColor White
Write-Host ""
Write-Host "• Registry Cleanup (if policy was set via registry):" -ForegroundColor Cyan
Write-Host "  Run these commands as Administrator to completely clean up:" -ForegroundColor White
Write-Host "  reg delete `"HKLM\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation`" /f" -ForegroundColor Gray
Write-Host ""
Write-Host "• Hyper-V Manager Connections:" -ForegroundColor Cyan
Write-Host "  - Remove any saved connections to remote Hyper-V hosts" -ForegroundColor White
Write-Host "  - Clear any stored credentials in Credential Manager if needed" -ForegroundColor White
Write-Host ""

# 5. Optional: Reset WinRM to defaults
Write-Host "5. Resetting WinRM configuration..." -ForegroundColor Yellow
$resetWinRM = Read-Host "Do you want to reset WinRM to default configuration? (y/N)"
if ($resetWinRM -eq 'y' -or $resetWinRM -eq 'Y') {
    try {
        winrm quickconfig -quiet
        Write-Host "   ✓ WinRM reset to default configuration" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to reset WinRM: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   - WinRM configuration left unchanged" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Revert Complete ===" -ForegroundColor Green
Write-Host "Hyper-V client remote management configuration has been reverted." -ForegroundColor White
Write-Host "The client will no longer be configured to connect to remote Hyper-V hosts." -ForegroundColor White
Write-Host ""
Write-Host "Note: A restart may be recommended for Group Policy changes to take full effect." -ForegroundColor Yellow
Write-Host "Note: You may need to run 'gpupdate /force' to refresh Group Policy immediately." -ForegroundColor Yellow
