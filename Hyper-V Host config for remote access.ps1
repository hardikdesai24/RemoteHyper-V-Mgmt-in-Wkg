# Hyper-V Host Configuration Script for Remote Management in a Workgroup

# 1. Enable PowerShell Remoting
Enable-PSRemoting -Force

# 2. Configure WSMan for remote management with CredSSP (secure for workgroups)
Enable-WSManCredSSP -Role Server -Force

# 3. Enable Hyper-V Management Firewall Rules (optional for migration/replication)
Enable-NetFirewallRule -DisplayGroup "Hyper-V"

# 4. Allow Remote WMI Access (required for Hyper-V Manager)
Enable-NetFirewallRule -Name "RPC-EPMAP"
Enable-NetFirewallRule -Name "WMI-WINMGMT-In-TCP"
Enable-NetFirewallRule -Name "WMI-RPCSS-In-TCP"

# 5. Enable Windows Remote Management firewall exception
Enable-NetFirewallRule -Name "WINRM-HTTP-In-TCP"

# 6. Enable DCOM for remote management (often default, but ensures compatibility)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y"

# 7. Add the remote management user to required local groups
# Replace 'RemoteUser' with the username
# Add-LocalGroupMember -Group "Hyper-V Administrators" -Member "RemoteUser"
# Add-LocalGroupMember -Group "Remote Management Users" -Member "RemoteUser"  # For WinRM access if not admin

# 8. Optional: Allow Remote Desktop
# Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

Write-Host "Hyper-V host is configured for remote management in a workgroup using CredSSP."
Write-Host "On the client PC (run as Administrator):"
Write-Host "1. Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force  # Or specify host FQDN/IP"
Write-Host "2. Enable-WSManCredSSP -Role Client -DelegateComputer '*' -Force  # Or specify host FQDN/IP"
Write-Host "3. Configure credential delegation policy (via gpedit.msc or registry):"
Write-Host "   - Enable 'Allow delegating fresh credentials with NTLM-only server authentication'"
Write-Host "   - Add 'wsman/*' or 'wsman/<host-fqdn>'"
Write-Host "4. In Hyper-V Manager, connect to the host's name/IP and provide credentials from 'Hyper-V Administrators' group."
Write-Host "Note: Use FQDN where possible for reliability. CredSSP secures credentials but requires a trusted network."