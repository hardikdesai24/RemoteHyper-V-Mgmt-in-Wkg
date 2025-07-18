# Configure Hyper-V Host (TOMHAWK) for remote management
# Run this script as Administrator on TOMHAWK

# Step 1: Enable WinRM service
winrm quickconfig -q

# Step 2: Enable CredSSP server role
Enable-WSManCredSSP -Role Server -Force

# Step 3: Delete and recreate WinRM HTTP listener
Try {
    winrm delete winrm/config/Listener?Address=*+Transport=HTTP
} Catch {
    Write-Host "No existing listener to delete or already removed."
}
winrm create winrm/config/Listener?Address=*+Transport=HTTP '@{Hostname="";Port="5985"}'

# Step 4: Enable required firewall rules
Enable-NetFirewallRule -DisplayGroup "Windows Management Instrumentation (WMI)"
Enable-NetFirewallRule -DisplayGroup "Hyper-V"
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"

# Step 5: Confirm listener status
Write-Host "`n=== WinRM Listener Configuration ==="
winrm enumerate winrm/config/listener

# Step 6: Confirm CredSSP server role enabled
Write-Host "`n=== WSMan CredSSP Settings ==="
Get-WSManCredSSP