# Hyper-V Client Configuration Script for Workgroup Environment
# Run this script on the client system with Hyper-V management tools
# Fixed syntax errors and completed the script

param(
    [string]$HostIP = "",
    [string]$Username = "",
    [string]$OutputPath = "C:\HyperV-Client-Config-Report.html"
)

# Initialize variables
$ErrorLog = @()
$SuccessLog = @()
$ScriptStartTime = Get-Date
$ClientName = $env:COMPUTERNAME

# Get client IP address with error handling for both Ethernet and vEthernet interfaces
try {
    $ClientIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias "Ethernet*","vEthernet*" | Where-Object {$_.IPAddress -notlike "169.254*" -and $_.IPAddress -notlike "127.*"} | Select-Object -First 1).IPAddress
    if (-not $ClientIP) {
        # Fallback to any non-loopback IPv4 address
        $ClientIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike "169.254*" -and $_.IPAddress -notlike "127.*"} | Select-Object -First 1).IPAddress
    }
} catch {
    $ClientIP = "Unknown"
}

if (-not $ClientIP) {
    $ClientIP = "Unknown"
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

# Function to test remote connection
function Test-RemoteConnection {
    param([string]$ComputerName, [pscredential]$Credential)
    
    try {
        Write-Host "Testing remote connection to $ComputerName..." -ForegroundColor Cyan
        
        # Test network connectivity
        $networkTest = Test-NetConnection -ComputerName $ComputerName -Port 5985 -InformationLevel Quiet
        if (-not $networkTest) {
            Write-ErrorLog "Network connectivity test failed to $ComputerName on port 5985"
            return $false
        }
        Write-SuccessLog "Network connectivity test successful to $ComputerName:5985"
        
        # Test WinRM connectivity with CredSSP
        try {
            $winrmTest = Test-WSMan -ComputerName $ComputerName -Authentication Credssp -Credential $Credential -ErrorAction Stop
            if ($winrmTest) {
                Write-SuccessLog "WinRM CredSSP connectivity test successful to $ComputerName"
            }
        } catch {
            Write-ErrorLog "WinRM CredSSP test failed, trying basic authentication" $_.Exception.Message
            # Fallback to basic authentication test
            try {
                $winrmTest = Test-WSMan -ComputerName $ComputerName -Authentication Basic -Credential $Credential -ErrorAction Stop
                if ($winrmTest) {
                    Write-SuccessLog "WinRM Basic authentication test successful to $ComputerName"
                }
            } catch {
                Write-ErrorLog "WinRM Basic authentication test also failed" $_.Exception.Message
                return $false
            }
        }
        
        # Test PowerShell remoting with CredSSP
        try {
            $sessionTest = New-PSSession -ComputerName $ComputerName -Credential $Credential -Authentication CredSSP -ErrorAction Stop
            if ($sessionTest) {
                Write-SuccessLog "PowerShell CredSSP remoting session established successfully"
                Remove-PSSession $sessionTest
            }
        } catch {
            Write-ErrorLog "CredSSP session failed, trying default authentication" $_.Exception.Message
            # Fallback to default authentication
            try {
                $sessionTest = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
                if ($sessionTest) {
                    Write-SuccessLog "PowerShell remoting session established with default authentication"
                    Remove-PSSession $sessionTest
                }
            } catch {
                Write-ErrorLog "PowerShell remoting failed with all authentication methods" $_.Exception.Message
                return $false
            }
        }
        
        return $true
        
    } catch {
        Write-ErrorLog "Remote connection test failed to $ComputerName" $_.Exception.Message
        return $false
    }
}

# Function to test Hyper-V management
function Test-HyperVManagement {
    param([string]$ComputerName, [pscredential]$Credential)
    
    try {
        Write-Host "Testing Hyper-V management capabilities..." -ForegroundColor Cyan
        
        # Test Hyper-V module availability
        try {
            $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -Authentication CredSSP -ErrorAction Stop
        } catch {
            # Fallback to default authentication if CredSSP fails
            $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
        }
        
        $hypervTest = Invoke-Command -Session $session -ScriptBlock {
            try {
                # Check if Hyper-V module is available
                $hypervModule = Get-Module -Name Hyper-V -ListAvailable
                if (-not $hypervModule) {
                    return @{Success = $false; Message = "Hyper-V module not available on host"}
                }
                
                # Try to get Hyper-V service status
                $hypervService = Get-Service -Name vmms -ErrorAction Stop
                if ($hypervService.Status -ne "Running") {
                    return @{Success = $false; Message = "Hyper-V Virtual Machine Management service not running"}
                }
                
                # Try to get VMs (basic test)
                $vms = Get-VM -ErrorAction Stop
                return @{Success = $true; Message = "Successfully connected to Hyper-V. VM count: $($vms.Count)"; VMCount = $vms.Count}
                
            } catch {
                return @{Success = $false; Message = "Error testing Hyper-V: $($_.Exception.Message)"}
            }
        }
        
        Remove-PSSession $session
        
        if ($hypervTest.Success) {
            Write-SuccessLog "Hyper-V management test successful. $($hypervTest.Message)"
            return $true
        } else {
            Write-ErrorLog "Hyper-V management test failed" $hypervTest.Message
            return $false
        }
        
    } catch {
        Write-ErrorLog "Failed to test Hyper-V management capabilities" $_.Exception.Message
        return $false
    }
}

# Function to generate HTML report
function New-HTMLReport {
    param([string]$OutputPath, [bool]$ConnectionSuccessful = $false, [string]$VMCount = "N/A")
    
    # Build HTML content step by step to avoid parsing issues
    $htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <title>Hyper-V Client Configuration Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 15px; border-radius: 5px; }
        .success { background-color: #d4edda; border: 1px solid #c3e6cb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .error { background-color: #f8d7da; border: 1px solid #f5c6cb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .info { background-color: #d1ecf1; border: 1px solid #bee5eb; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .warning { background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; margin: 10px 0; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .timestamp { font-size: 0.9em; color: #666; }
        .command { background-color: #f8f9fa; padding: 10px; border-left: 4px solid #007bff; margin: 10px 0; font-family: monospace; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Hyper-V Client Configuration Report</h1>
        <p>Client: $ClientName ($ClientIP)</p>
        <p>Target Host: $HostIP</p>
        <p>Execution Time: $ScriptStartTime</p>
    </div>
    
    <div class="info">
        <h3>Configuration Summary</h3>
        <p><strong>Total Errors:</strong> $($ErrorLog.Count)</p>
        <p><strong>Total Success Operations:</strong> $($SuccessLog.Count)</p>
        <p><strong>Connection Status:</strong> $(if ($ConnectionSuccessful) { "✅ CONNECTED" } else { "❌ FAILED" })</p>
        <p><strong>VM Count on Host:</strong> $VMCount</p>
        <p><strong>Overall Status:</strong> $(if ($ErrorLog.Count -eq 0 -and $ConnectionSuccessful) { "✅ SUCCESS" } else { "❌ FAILED" })</p>
    </div>
"@

    $html = $htmlHeader

    if ($SuccessLog.Count -gt 0) {
        $successSection = @"
    <div class="success">
        <h3>✅ Successful Operations</h3>
        <table>
            <tr><th>Time</th><th>Function</th><th>Message</th></tr>
"@
        foreach ($entry in $SuccessLog) {
            $successSection += "<tr><td class='timestamp'>$($entry.Time)</td><td>$($entry.Function)</td><td>$($entry.Message)</td></tr>"
        }
        $successSection += "</table></div>"
        $html += $successSection
    }

    if ($ErrorLog.Count -gt 0) {
        $errorSection = @"
    <div class="error">
        <h3>❌ Errors Encountered</h3>
        <table>
            <tr><th>Time</th><th>Function</th><th>Message</th><th>Exception</th></tr>
"@
        foreach ($entry in $ErrorLog) {
            $errorSection += "<tr><td class='timestamp'>$($entry.Time)</td><td>$($entry.Function)</td><td>$($entry.Message)</td><td>$($entry.Exception)</td></tr>"
        }
        $errorSection += "</table></div>"
        $html += $errorSection
    }

    if ($ConnectionSuccessful) {
        $successConnectionSection = @"
    <div class="success">
        <h3>🎉 Connection Successful!</h3>
        <p>You can now use the following commands to manage Hyper-V remotely:</p>
        <div class="command">
# Create a persistent session<br>
`$session = New-PSSession -ComputerName $HostIP -Credential (Get-Credential)<br><br>

# Get all VMs<br>
Invoke-Command -Session `$session -ScriptBlock { Get-VM }<br><br>

# Start a VM<br>
Invoke-Command -Session `$session -ScriptBlock { Start-VM -Name "VMName" }<br><br>

# Get VM status<br>
Invoke-Command -Session `$session -ScriptBlock { Get-VM -Name "VMName" | Select-Object Name, State, Status }<br><br>

# Clean up session<br>
Remove-PSSession `$session
        </div>
    </div>
"@
        $html += $successConnectionSection
    } else {
        $failedConnectionSection = @"
    <div class="warning">
        <h3>⚠️ Connection Failed</h3>
        <p>Troubleshooting steps:</p>
        <ul>
            <li>Verify the host script completed successfully</li>
            <li>Check network connectivity: <code>Test-NetConnection -ComputerName $HostIP -Port 5985</code></li>
            <li>Verify WinRM is running on host: <code>Get-Service WinRM</code></li>
            <li>Check firewall settings on both systems</li>
            <li>Verify credentials are correct</li>
            <li>Ensure both systems are in the same network segment</li>
            <li><strong>CredSSP Specific Issues:</strong></li>
            <ul>
                <li>Restart the client machine after CredSSP configuration</li>
                <li>Verify Group Policy delegation settings: <code>gpedit.msc</code></li>
                <li>Check CredSSP registry settings under HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation</li>
                <li>Try manual connection: <code>New-PSSession -ComputerName $HostIP -Credential (Get-Credential) -Authentication CredSSP</code></li>
            </ul>
        </ul>
    </div>
"@
        $html += $failedConnectionSection
    }

    $htmlFooter = @"
    <div class="info">
        <h3>System Information</h3>
        <p><strong>Client OS:</strong> $((Get-CimInstance Win32_OperatingSystem).Caption)</p>
        <p><strong>PowerShell Version:</strong> $($PSVersionTable.PSVersion)</p>
        <p><strong>Hyper-V Management Tools:</strong> $(if (Get-Module -Name Hyper-V -ListAvailable) { "✅ Installed" } else { "❌ Not Installed" })</p>
    </div>
    
    <div class="info">
        <p><em>Report generated on: $(Get-Date)</em></p>
    </div>
</body>
</html>
"@

    $html += $htmlFooter

    try {
        $html | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-Host "HTML report generated: $OutputPath" -ForegroundColor Cyan
    } catch {
        Write-Host "Failed to generate HTML report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution block
try {
    Write-Host "Starting Hyper-V Client Configuration..." -ForegroundColor Cyan
    Write-Host "Client: $ClientName ($ClientIP)" -ForegroundColor Cyan
    
    # Get input parameters if not provided
    if (-not $HostIP) {
        $HostIP = Read-Host "Enter the IP address of the Hyper-V host"
    }
    if (-not $Username) {
        $Username = Read-Host "Enter the username for the Hyper-V host"
    }
    
    # Get credentials
    Write-Host "Please enter credentials for the Hyper-V host..." -ForegroundColor Cyan
    $Credential = Get-Credential -UserName $Username -Message "Enter credentials for $HostIP"
    
    if (-not $Credential) {
        Write-ErrorLog "No credentials provided"
        return
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

    # 2. Check Hyper-V Management Tools
    try {
        $hypervModule = Get-Module -Name Hyper-V -ListAvailable
        if (-not $hypervModule) {
            Write-ErrorLog "Hyper-V Management Tools not installed. Install using: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell"
            return
        }
        Write-SuccessLog "Hyper-V Management Tools are installed"
    } catch {
        Write-ErrorLog "Failed to check Hyper-V Management Tools" $_.Exception.Message
    }

    # 3. Configure WinRM Client with CredSSP
    try {
        $winrmService = Get-Service -Name WinRM -ErrorAction SilentlyContinue
        if ($winrmService.Status -ne "Running") {
            Start-Service -Name WinRM
            Write-SuccessLog "WinRM service started"
        } else {
            Write-SuccessLog "WinRM service already running"
        }
        
        # Configure WinRM client settings
        winrm set winrm/config/client '@{TrustedHosts="*"}'
        Write-SuccessLog "WinRM client trusted hosts configured"
        
        # Enable CredSSP on client
        Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force
        Write-SuccessLog "CredSSP client authentication enabled"
        
        # Configure Group Policy for CredSSP delegation
        try {
            $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
            if (-not (Test-Path $regPath)) {
                New-Item -Path $regPath -Force | Out-Null
            }
            
            # Allow delegating fresh credentials
            Set-ItemProperty -Path $regPath -Name "AllowFreshCredentials" -Value 1 -Type DWord
            Set-ItemProperty -Path $regPath -Name "ConcatenateDefaults_AllowFresh" -Value 1 -Type DWord
            
            # Create the AllowFreshCredentialsList
            $listPath = "$regPath\AllowFreshCredentialsList"
            if (-not (Test-Path $listPath)) {
                New-Item -Path $listPath -Force | Out-Null
            }
            Set-ItemProperty -Path $listPath -Name "1" -Value "wsman/*" -Type String
            
            # Allow delegating fresh credentials with NTLM-only server authentication
            Set-ItemProperty -Path $regPath -Name "AllowFreshCredentialsWhenNTLMOnly" -Value 1 -Type DWord
            Set-ItemProperty -Path $regPath -Name "ConcatenateDefaults_AllowFreshNTLMOnly" -Value 1 -Type DWord
            
            # Create the AllowFreshCredentialsWhenNTLMOnlyList
            $ntlmListPath = "$regPath\AllowFreshCredentialsWhenNTLMOnlyList"
            if (-not (Test-Path $ntlmListPath)) {
                New-Item -Path $ntlmListPath -Force | Out-Null
            }
            Set-ItemProperty -Path $ntlmListPath -Name "1" -Value "wsman/*" -Type String
            
            Write-SuccessLog "CredSSP Group Policy delegation configured via registry"
        } catch {
            Write-ErrorLog "Failed to configure CredSSP Group Policy settings" $_.Exception.Message
        }
        
        # Enable basic authentication (fallback)
        winrm set winrm/config/client/auth '@{Basic="true"}'
        Write-SuccessLog "WinRM client basic authentication enabled"
        
        # Enable Kerberos authentication
        winrm set winrm/config/client/auth '@{Kerberos="true"}'
        Write-SuccessLog "WinRM client Kerberos authentication enabled"
        
        # Enable CredSSP authentication
        winrm set winrm/config/client/auth '@{CredSSP="true"}'
        Write-SuccessLog "WinRM client CredSSP authentication enabled"
        
        # Force a Group Policy update
        try {
            gpupdate /force | Out-Null
            Write-SuccessLog "Group Policy updated successfully"
        } catch {
            Write-ErrorLog "Failed to update Group Policy" $_.Exception.Message
        }
        
    } catch {
        Write-ErrorLog "Failed to configure WinRM client with CredSSP" $_.Exception.Message
    }

    # 4. Test network connectivity
    try {
        Write-Host "Testing network connectivity to $HostIP..." -ForegroundColor Cyan
        $networkTest = Test-NetConnection -ComputerName $HostIP -Port 5985 -InformationLevel Detailed
        if ($networkTest.TcpTestSucceeded) {
            Write-SuccessLog "Network connectivity successful to $HostIP:5985"
        } else {
            Write-ErrorLog "Network connectivity failed to $HostIP:5985. Check firewall and network settings."
        }
    } catch {
        Write-ErrorLog "Network connectivity test failed" $_.Exception.Message
    }

    # 5. Test remote connection
    $connectionSuccessful = Test-RemoteConnection -ComputerName $HostIP -Credential $Credential
    
    # 6. Test Hyper-V management if connection successful
    $vmCount = "N/A"
    if ($connectionSuccessful) {
        $hypervTest = Test-HyperVManagement -ComputerName $HostIP -Credential $Credential
        if ($hypervTest) {
            # Get VM count for reporting
            try {
                try {
                    $session = New-PSSession -ComputerName $HostIP -Credential $Credential -Authentication CredSSP -ErrorAction Stop
                } catch {
                    # Fallback to default authentication if CredSSP fails
                    $session = New-PSSession -ComputerName $HostIP -Credential $Credential -ErrorAction Stop
                }
                $vmCount = Invoke-Command -Session $session -ScriptBlock {
                    $vms = Get-VM -ErrorAction SilentlyContinue
                    return $vms.Count
                }
                Remove-PSSession $session
            } catch {
                Write-ErrorLog "Failed to get VM count" $_.Exception.Message
            }
        }
    }

    # 7. Generate HTML report
    Write-Host "Generating HTML report..." -ForegroundColor Cyan
    New-HTMLReport -OutputPath $OutputPath -ConnectionSuccessful $connectionSuccessful -VMCount $vmCount

    # 8. Final summary
    Write-Host "`nConfiguration Summary:" -ForegroundColor Cyan
    Write-Host "Total Errors: $($ErrorLog.Count)" -ForegroundColor $(if ($ErrorLog.Count -eq 0) { "Green" } else { "Red" })
    Write-Host "Total Success Operations: $($SuccessLog.Count)" -ForegroundColor Green
    Write-Host "Connection Status: $(if ($connectionSuccessful) { "CONNECTED" } else { "FAILED" })" -ForegroundColor $(if ($connectionSuccessful) { "Green" } else { "Red" })
    Write-Host "VM Count on Host: $vmCount" -ForegroundColor Cyan
    Write-Host "Overall Status: $(if ($ErrorLog.Count -eq 0 -and $connectionSuccessful) { "SUCCESS" } else { "FAILED" })" -ForegroundColor $(if ($ErrorLog.Count -eq 0 -and $connectionSuccessful) { "Green" } else { "Red" })
    Write-Host "Report saved to: $OutputPath" -ForegroundColor Cyan

} catch {
    Write-ErrorLog "Critical error in main execution block" $_.Exception.Message
    Write-Host "Critical error occurred. Check the HTML report for details." -ForegroundColor Red
    
    # Generate report even if there's a critical error
    try {
        New-HTMLReport -OutputPath $OutputPath -ConnectionSuccessful $false -VMCount "N/A"
    } catch {
        Write-Host "Failed to generate error report: $($_.Exception.Message)" -ForegroundColor Red
    }
} finally {
    # Clean up any remaining sessions
    try {
        Get-PSSession | Remove-PSSession -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup errors
    }
    
    Write-Host "`nScript execution completed." -ForegroundColor Cyan
}