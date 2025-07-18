# Hyper-V Remote Management in Workgroup Environment

A comprehensive solution for enabling secure remote Hyper-V management between computers in a workgroup (non-domain) environment using CredSSP authentication.

## 📋 Overview

This repository contains PowerShell scripts and documentation for configuring Hyper-V remote management in workgroup environments. The solution uses CredSSP (Credential Security Support Provider) to provide secure credential delegation between the client and host systems.

## 🗂️ Files Structure

### Core Scripts
- [`Hyper-V Host Config (Claude).ps1`](Hyper-V%20Host%20Config%20(Claude).ps1) - **Advanced host configuration script** with comprehensive error handling and HTML reporting
- [`Hyper-V Client Configuration Script (Claude).ps1`](Hyper-V%20Client%20Configuration%20Script%20(Claude).ps1) - **Advanced client configuration script** with connection testing and detailed reporting

### Simple Scripts
- [`Hyper-V Host config for remote access.ps1`](Hyper-V%20Host%20config%20for%20remote%20access.ps1) - Basic host configuration script
- [`Hyper-V Client config for remote access.ps1`](Hyper-V%20Client%20config%20for%20remote%20access.ps1) - Basic client configuration script
- [`Configure-HyperVHost.ps1`](Configure-HyperVHost.ps1) - Simple host setup script
- [`Configure-RemoteHyperV-Client.ps1`](Configure-RemoteHyperV-Client.ps1) - Simple client setup script

### Cleanup Scripts
- [`Hyper-V Host config REVERT.ps1`](Hyper-V%20Host%20config%20REVERT.ps1) - Reverts host configuration changes
- [`Hyper-V Client config REVERT.ps1`](Hyper-V%20Client%20config%20REVERT.ps1) - Reverts client configuration changes

### Documentation
- [`CredSSP-Configuration-Guide.md`](CredSSP-Configuration-Guide.md) - **Comprehensive troubleshooting guide** with confirmed working solutions

## 🚀 Quick Start

### Prerequisites
- Windows 10/11 or Windows Server with Hyper-V
- PowerShell 5.1 or later
- Administrator privileges on both systems
- Network connectivity between client and host

### ✅ Recommended Approach (Advanced Scripts)

#### Step 1: Configure the Hyper-V Host
Run on the Hyper-V host machine as Administrator:

```powershell
.\Hyper-V Host Config (Claude).ps1
```

This script will:
- ✅ Enable CredSSP server authentication
- ✅ Configure WinRM with multiple authentication methods
- ✅ Set up Windows Firewall rules
- ✅ Add users to Hyper-V Administrators group
- ✅ Generate detailed HTML report

#### Step 2: Configure the Client
Run on the client machine (with Hyper-V Manager) as Administrator:

```powershell
.\Hyper-V Client Configuration Script (Claude).ps1
```

This script will:
- ✅ Enable CredSSP client authentication
- ✅ Configure credential delegation
- ✅ Test network connectivity
- ✅ Verify Hyper-V management capabilities
- ✅ Generate detailed HTML report

#### Step 3: Manual Configuration (Critical)
⚠️ **IMPORTANT:** Manual steps are required for CredSSP to work properly:

1. **Configure Group Policy** (run `gpedit.msc` as Administrator):
   - Navigate to: `Computer Configuration → Administrative Templates → System → Credentials Delegation`
   - Enable: "Allow delegating fresh credentials with NTLM-only server authentication"
   - Add to server list: `wsman/*`

2. **Restart the client machine** - This is mandatory for CredSSP changes to take effect

#### Step 4: Test Connection
```powershell
New-PSSession -ComputerName "HOST_IP" -Credential (Get-Credential) -Authentication CredSSP
```

## 🛠️ Alternative Methods

### Simple Scripts
For basic setups without advanced error handling:

**Host:**
```powershell
.\Hyper-V Host config for remote access.ps1
```

**Client:**
```powershell
.\Hyper-V Client config for remote access.ps1
```

### Manual Registry Configuration
If Group Policy Editor is not available:

```powershell
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation"
New-Item -Path $regPath -Force
Set-ItemProperty -Path $regPath -Name "AllowFreshCredentialsWhenNTLMOnly" -Value 1 -Type DWord
New-Item -Path "$regPath\AllowFreshCredentialsWhenNTLMOnlyList" -Force
Set-ItemProperty -Path "$regPath\AllowFreshCredentialsWhenNTLMOnlyList" -Name "1" -Value "wsman/*" -Type String
```

## 🔧 Troubleshooting

### Common Issues

1. **"WinRM client could not process the request because credentials were specified along with the 'no authentication' flag"**
   - Solution: Configure Group Policy delegation manually + restart client

2. **Connection timeout or access denied**
   - Check firewall settings on both systems
   - Verify credentials are correct
   - Ensure user is in "Hyper-V Administrators" group

3. **CredSSP authentication failed**
   - Restart client machine after configuration
   - Verify Group Policy settings
   - Check registry delegation settings

### Debug Commands
```powershell
# Test network connectivity
Test-NetConnection -ComputerName "HOST_IP" -Port 5985

# Check CredSSP status
Get-WSManCredSSP

# Check WinRM configuration
winrm get winrm/config/client/auth
winrm get winrm/config/service/auth

# Manual session test
New-PSSession -ComputerName "HOST_IP" -Credential (Get-Credential) -Authentication CredSSP
```

## 📊 Features

### Advanced Scripts Features
- ✅ **Comprehensive error handling** with detailed logging
- ✅ **HTML report generation** for troubleshooting
- ✅ **Multiple authentication fallbacks** (CredSSP → Basic → Default)
- ✅ **Network connectivity testing** before configuration
- ✅ **Automatic credential delegation setup**
- ✅ **VM count verification** and management testing
- ✅ **Automatic IP address detection**

### Security Features
- 🔒 **CredSSP encryption** for secure credential delegation
- 🔒 **Firewall rule configuration** for specific client IPs
- 🔒 **Proper user group management** (Hyper-V Administrators)
- 🔒 **Multiple authentication methods** for compatibility

## 🧹 Cleanup

To revert all changes:

**Host:**
```powershell
.\Hyper-V Host config REVERT.ps1
```

**Client:**
```powershell
.\Hyper-V Client config REVERT.ps1
```

## 📝 Success Confirmation

According to [`CredSSP-Configuration-Guide.md`](CredSSP-Configuration-Guide.md), the confirmed working solution includes:
- ✅ Host script: 14+ successful operations
- ✅ Client script: Enhanced authentication with fallbacks
- ✅ Manual Group Policy configuration
- ✅ Client machine restart
- ✅ Full Hyper-V remote management working

## 🔍 Documentation

For detailed troubleshooting and confirmed solutions, see:
- [`CredSSP-Configuration-Guide.md`](CredSSP-Configuration-Guide.md) - Complete troubleshooting guide with working solutions

## ⚠️ Important Notes

1. **Client restart is mandatory** after CredSSP configuration
2. **Group Policy configuration cannot be automated** - must be done manually
3. **Registry configuration alone is insufficient** - Group Policy is required
4. **Use in trusted networks only** - CredSSP delegates credentials
5. **Test in lab environment first** before production use

## 🎯 Success Criteria

Configuration is successful when:
- ✅ Network connectivity test passes (port 5985)
- ✅ CredSSP authentication works
- ✅ PowerShell remoting session established
- ✅ Hyper-V management commands work remotely
- ✅ VM count can be retrieved from host

## 📞 Support

If you encounter issues:
1. Check the generated HTML reports for detailed error information
2. Review the [`CredSSP-Configuration-Guide.md`](CredSSP-Configuration-Guide.md) for known solutions
3. Verify all manual configuration steps are completed
4. Ensure client machine has been restarted after CredSSP setup

---

**🎉 Configuration now working successfully for Hyper-V remote management with CredSSP security!**