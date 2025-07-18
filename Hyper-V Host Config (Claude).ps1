# Hyper-V Host Configuration Script for Workgroup Environment
# Run this script on the Hyper-V host with administrative privileges

param(
    [string]$ClientIP = "",
    [string]$Username = "",
    [string]$OutputPath = "C:\HyperV-Host-Config-Report.html"
)

# Initialize variables
$ErrorLog = @()
$SuccessLog = @()
$ScriptStartTime = Get-Date
$HostName = $env:COMPUTERNAME

# Get host IP address with error handling for both Ethernet and vEthernet interfaces
try {
    $HostIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*","vEthernet*" | Where-Object {$_.IPAddress -notlike "169.254*" -and $_.IPAddress -notlike "127.*"} | Select-Object -First 1).IPAddress
    if (-not $HostIP) {
        # Fallback to any non-loopback IPv4 address
        $HostIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike "169.254*" -and $_.IPAddress -notlike "127.*"} | Select-Object -First 1).IPAddress
    }
} catch {
    $HostIP = "Unknown"
}

if (-not $HostIP) {
    $HostIP = "Unknown"
}

# Function to log errors
function Write-ErrorLog {
    param([string]$Message, [string]$Exception = "")
    $ErrorEntry = @{
        Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Message = $Message
        Exception = $Exception
        Function = (Get-PSCallStack)[1].Command
    }
    $script:ErrorLog += $ErrorEntry
    Write-Host "ERROR: $Message" -ForegroundColor Red
    if ($Exception) {
        Write-Host "Exception: $Exception" -ForegroundColor Yellow
    }
}

# Function to log success
function Write-SuccessLog {
    param([string]$Message)
    $SuccessEntry = @{
        Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Message = $Message
        Function = (Get-PSCallStack)[1].Command
    }
    $script:SuccessLog += $SuccessEntry
    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

# Function to generate HTML report
function New-HTMLReport {
    param([string]$OutputPath)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Hyper-V Host Configuration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 15px; border-radius: 5px; }
        .success { background-color: #d4edda; border: 1px solid #c3e6cb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .error { background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .info { background-color: #d1ecf1; border: 1px solid #bee5eb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .timestamp { font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Hyper-V Host Configuration Report</h1>
        <p>Host: $HostName ($HostIP)</p>
        <p>Execution Time: $ScriptStartTime</p>
    </div>
    
    <div class="info">
        <h3>Configuration Summary</h3>
        <p><strong>Total Errors:</strong> $($ErrorLog.Count)</p>
        <p><strong>Total Success Operations:</strong> $($SuccessLog.Count)</p>
        <p><strong>Overall Status:</strong> $(if ($ErrorLog.Count -eq 0) { "✅ SUCCESS" } else { "❌ FAILED" })</p>
    </div>
"@

    if ($SuccessLog.Count -gt 0) {
        $html += @"
    <div class="success">
        <h3>✅ Successful Operations</h3>
        <table>
            <tr><th>Time</th><th>Function</th><th>Message</th></tr>
"@
        foreach ($entry in $SuccessLog) {
            $html += "<tr><td class='timestamp'>$($entry.Time)</td><td>$($entry.Function)</td><td>$($entry.Message)</td></tr>"
        }
        $html += "</table></div>"
    }

    if ($ErrorLog.Count -gt 0) {
        $html += @"
    <div class="error">
        <h3>❌ Errors Encountered</h3>
        <table>
            <tr><th>Time</th><th>Function</th><th>Message</th><th>Exception</th></tr>
"@
        foreach ($entry in $ErrorLog) {
            $html += "<tr><td class='timestamp'>$($entry.Time)</td><td>$($entry.Function)</td><td>$($entry.Message)</td><td>$($entry.Exception)</td></tr>"
        }
        $html += "</table></div>"
    }

    $html += @"
    <div class="info">
        <h3>Next Steps</h3>
        <ul>
            <li>If successful, run the client script on the remote management system</li>
            <li>Use the following connection details:</li>
            <ul>
                <li><strong>Host IP:</strong> $HostIP</li>
                <li><strong>Username:</strong> $Username</li>
                <li><strong>Authentication:</strong> CredSSP (Secure)</li>
                <li><strong>Connection Test:</strong> Test-NetConnection -ComputerName $HostIP -Port 5985</li>
            </ul>
            <li><strong>Required Client Configuration:</strong></li>
            <ul>
                <li>Enable-WSManCredSSP -Role Client -DelegateComputer '$HostIP' -Force</li>
                <li>Configure Group Policy for credential delegation (or use registry)</li>
                <li>Add 'wsman/$HostIP' to credential delegation list</li>
                <li>Restart the client machine after CredSSP configuration</li>
                <li>Test: New-PSSession -ComputerName '$HostIP' -Authentication CredSSP</li>
            </ul>
        </ul>
    </div>
    
    <div class="info">
        <p><em>Report generated on: $(Get-Date)</em></p>
    </div>
</body>
</html>
"@

    try {
        $html | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "HTML report generated: $OutputPath" -ForegroundColor Cyan
    } catch {
        Write-Host "Failed to generate HTML report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution block
try {
    Write-Host "Starting Hyper-V Host Configuration..." -ForegroundColor Cyan
    Write-Host "Host: $HostName ($HostIP)" -ForegroundColor Cyan
    
    # Get input parameters if not provided
    if (-not $ClientIP) {
        $ClientIP = Read-Host "Enter the IP address of the client system"
    }
    if (-not $Username) {
        $Username = Read-Host "Enter the username for remote access"
    }

    # 1. Check if running as administrator
    try {
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-ErrorLog "Script must be run as Administrator"
            return
        }
        Write-SuccessLog "Running with Administrator privileges"
    } catch {
        Write-ErrorLog "Failed to check administrator privileges" $_.Exception.Message
        return
    }

    # 2. Enable Hyper-V Management Tools
    try {
        $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-Management-PowerShell"
        if ($hypervFeature.State -ne "Enabled") {
            Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-Management-PowerShell" -All -NoRestart
            Write-SuccessLog "Hyper-V Management PowerShell feature enabled"
        } else {
            Write-SuccessLog "Hyper-V Management PowerShell feature already enabled"
        }
    } catch {
        Write-ErrorLog "Failed to enable Hyper-V Management PowerShell feature" $_.Exception.Message
    }

    # 3. Configure WinRM with CredSSP
    try {
        $winrmConfig = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        if ($winrmConfig.Status -ne "Running") {
            Start-Service -Name WinRM
            Write-SuccessLog "WinRM service started"
        } else {
            Write-SuccessLog "WinRM service already running"
        }
        
        # Configure WinRM for workgroup
        winrm quickconfig -force
        Write-SuccessLog "WinRM quick configuration completed"
        
        # Enable CredSSP authentication on server
        Enable-WSManCredSSP -Role Server -Force
        Write-SuccessLog "CredSSP authentication enabled on server"
        
        # Enable basic authentication (fallback)
        winrm set winrm/config/service/auth '@{Basic="true"}'
        Write-SuccessLog "WinRM Basic authentication enabled"
        
        # Enable Kerberos authentication
        winrm set winrm/config/service/auth '@{Kerberos="true"}'
        Write-SuccessLog "WinRM Kerberos authentication enabled"
        
        # Set trusted hosts (for workgroup environment)
        winrm set winrm/config/client '@{TrustedHosts="*"}'
        Write-SuccessLog "WinRM trusted hosts configured"
        
        # Configure CredSSP delegation
        winrm set winrm/config/service/auth '@{CredSSP="true"}'
        Write-SuccessLog "CredSSP delegation configured"
        
    } catch {
        Write-ErrorLog "Failed to configure WinRM with CredSSP" $_.Exception.Message
    }

    # 4. Configure Windows Firewall
    try {
        # Enable WinRM firewall rules
        Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
        Write-SuccessLog "Windows Remote Management firewall rules enabled"
        
        # Create specific rule for client IP if provided
        if ($ClientIP -ne "*") {
            $ruleName = "Hyper-V Remote Management - $ClientIP"
            $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            if (-not $existingRule) {
                New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort 5985 -RemoteAddress $ClientIP -Action Allow
                Write-SuccessLog "Firewall rule created for client IP: $ClientIP"
            } else {
                Write-SuccessLog "Firewall rule already exists for client IP: $ClientIP"
            }
        }
    } catch {
        Write-ErrorLog "Failed to configure Windows Firewall" $_.Exception.Message
    }

    # 5. Configure Local Security Policy
    try {
        # Add user to Hyper-V Administrators group
        $hypervAdmins = "Hyper-V Administrators"
        try {
            Add-LocalGroupMember -Group $hypervAdmins -Member $Username -ErrorAction Stop
            Write-SuccessLog "User '$Username' added to Hyper-V Administrators group"
        } catch [Microsoft.PowerShell.Commands.MemberExistsException] {
            Write-SuccessLog "User '$Username' already member of Hyper-V Administrators group"
        }
        
        # Configure local security policy for network access
        $secpolConfig = @'
[System Access]
[Event Audit]
[Registry Values]
[Registry Keys]
[File Security]
[Kerberos Policy]
[System Log]
[Application Log]
[Security Log]
[Privilege Rights]
SeNetworkLogonRight = *S-1-1-0,*S-1-5-32-544,*S-1-5-32-545,*S-1-5-32-551
'@
        
        $tempFile = "$env:TEMP\secpol.inf"
        $secpolConfig | Out-File -FilePath $tempFile -Encoding ASCII
        secedit /configure /db secedit.sdb /cfg $tempFile /areas USER_RIGHTS
        Remove-Item $tempFile -Force
        Write-SuccessLog "Local security policy configured for network logon"
        
    } catch {
        Write-ErrorLog "Failed to configure local security policy" $_.Exception.Message
    }

    # 6. Test WinRM connectivity
    try {
        $testResult = Test-WSMan -ComputerName localhost -ErrorAction Stop
        if ($testResult) {
            Write-SuccessLog "WinRM connectivity test successful"
        }
    } catch {
        Write-ErrorLog "WinRM connectivity test failed" $_.Exception.Message
    }

    # 7. Display connection information
    Write-Host "`n=== Connection Information ===" -ForegroundColor Cyan
    Write-Host "Host IP: $HostIP" -ForegroundColor Yellow
    Write-Host "Username: $Username" -ForegroundColor Yellow
    Write-Host "WinRM Port: 5985" -ForegroundColor Yellow
    Write-Host "Authentication: CredSSP (Secure)" -ForegroundColor Yellow
    Write-Host "Test Command: Test-NetConnection -ComputerName $HostIP -Port 5985" -ForegroundColor Yellow
    Write-Host "`nClient Configuration Required:" -ForegroundColor Cyan
    Write-Host "1. Enable-WSManCredSSP -Role Client -DelegateComputer '$HostIP' -Force" -ForegroundColor White
    Write-Host "2. Configure Group Policy for credential delegation (or use registry)" -ForegroundColor White
    Write-Host "3. Add 'wsman/$HostIP' to credential delegation list" -ForegroundColor White
    Write-Host "4. Restart the client machine after CredSSP configuration" -ForegroundColor Yellow
    Write-Host "5. Test connection: New-PSSession -ComputerName $HostIP -Authentication CredSSP" -ForegroundColor White

} catch {
    Write-ErrorLog "Unexpected error during script execution" $_.Exception.Message
} finally {
    # Generate HTML report
    New-HTMLReport -OutputPath $OutputPath
    
    # Summary
    Write-Host "`n=== Configuration Summary ===" -ForegroundColor Cyan
    Write-Host "Total Errors: $($ErrorLog.Count)" -ForegroundColor $(if ($ErrorLog.Count -eq 0) { "Green" } else { "Red" })
    Write-Host "Total Success Operations: $($SuccessLog.Count)" -ForegroundColor Green
    Write-Host "Overall Status: $(if ($ErrorLog.Count -eq 0) { "SUCCESS" } else { "FAILED" })" -ForegroundColor $(if ($ErrorLog.Count -eq 0) { "Green" } else { "Red" })
    Write-Host "HTML Report: $OutputPath" -ForegroundColor Cyan
    
    if ($ErrorLog.Count -eq 0) {
        Write-Host "`n✅ Host configuration completed successfully!" -ForegroundColor Green
        Write-Host "You can now run the client script on the remote management system." -ForegroundColor Green
    } else {
        Write-Host "`n❌ Host configuration completed with errors!" -ForegroundColor Red
        Write-Host "Please review the HTML report for detailed error information." -ForegroundColor Red
    }
}