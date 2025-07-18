# Hyper-V Host Configuration Revert Script
# This script reverts the changes made by "Hyper-V Host config for remote access.ps1"

Write-Host "=== Reverting Hyper-V Host Configuration ===" -ForegroundColor Red
Write-Host "This will disable remote management capabilities configured for workgroup access." -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "Are you sure you want to proceed? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""

# 1. Disable PowerShell Remoting
Write-Host "1. Disabling PowerShell Remoting..." -ForegroundColor Yellow
try {
    Disable-PSRemoting -Force
    Write-Host "   ✓ PowerShell Remoting disabled" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to disable PowerShell Remoting: $_" -ForegroundColor Red
}

# 2. Disable CredSSP Server Role
Write-Host "2. Disabling CredSSP Server..." -ForegroundColor Yellow
try {
    Disable-WSManCredSSP -Role Server
    Write-Host "   ✓ CredSSP Server disabled" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to disable CredSSP Server: $_" -ForegroundColor Red
}

# 3. Disable Hyper-V Management Firewall Rules
Write-Host "3. Disabling Hyper-V Management Firewall Rules..." -ForegroundColor Yellow
try {
    Disable-NetFirewallRule -DisplayGroup "Hyper-V"
    Write-Host "   ✓ Hyper-V firewall rules disabled" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to disable Hyper-V firewall rules: $_" -ForegroundColor Red
}

# 4. Disable Remote WMI Access
Write-Host "4. Disabling Remote WMI Access..." -ForegroundColor Yellow
try {
    Disable-NetFirewallRule -Name "RPC-EPMAP"
    Disable-NetFirewallRule -Name "WMI-WINMGMT-In-TCP"
    Disable-NetFirewallRule -Name "WMI-RPCSS-In-TCP"
    Write-Host "   ✓ WMI firewall rules disabled" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to disable WMI firewall rules: $_" -ForegroundColor Red
}

# 5. Disable Windows Remote Management firewall exception
Write-Host "5. Disabling Windows Remote Management firewall..." -ForegroundColor Yellow
try {
    Disable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"
    Write-Host "   ✓ WinRM firewall rule disabled" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to disable WinRM firewall rule: $_" -ForegroundColor Red
}

# 6. Reset DCOM setting (set to default)
Write-Host "6. Resetting DCOM configuration..." -ForegroundColor Yellow
try {
    # Note: 'Y' is typically the default, but we'll remove the explicit setting
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -ErrorAction SilentlyContinue
    Write-Host "   ✓ DCOM setting reset to default" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to reset DCOM setting: $_" -ForegroundColor Red
}

# 7. Display manual cleanup instructions
Write-Host ""
Write-Host "=== Manual Cleanup Required ===" -ForegroundColor Yellow
Write-Host "The following require manual attention:" -ForegroundColor White
Write-Host ""
Write-Host "• Local Group Members:" -ForegroundColor Cyan
Write-Host "  - Review and remove users from 'Hyper-V Administrators' group if needed" -ForegroundColor White
Write-Host "  - Review and remove users from 'Remote Management Users' group if needed" -ForegroundColor White
Write-Host ""
Write-Host "• Remote Desktop (if enabled):" -ForegroundColor Cyan
Write-Host "  - Run: Disable-NetFirewallRule -DisplayGroup 'Remote Desktop'" -ForegroundColor White
Write-Host ""

# 8. Optional: Stop and disable WinRM service
Write-Host "8. Stopping WinRM Service..." -ForegroundColor Yellow
$stopWinRM = Read-Host "Do you want to stop and disable the WinRM service? (y/N)"
if ($stopWinRM -eq 'y' -or $stopWinRM -eq 'Y') {
    try {
        Stop-Service WinRM -Force
        Set-Service WinRM -StartupType Disabled
        Write-Host "   ✓ WinRM service stopped and disabled" -ForegroundColor Green
    } catch {
        Write-Host "   ✗ Failed to stop/disable WinRM service: $_" -ForegroundColor Red
    }
} else {
    Write-Host "   - WinRM service left running" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Revert Complete ===" -ForegroundColor Green
Write-Host "Hyper-V host remote management has been disabled." -ForegroundColor White
Write-Host "The host will no longer accept remote Hyper-V connections." -ForegroundColor White
Write-Host ""
Write-Host "Note: A restart may be recommended to ensure all changes take effect." -ForegroundColor Yellow
