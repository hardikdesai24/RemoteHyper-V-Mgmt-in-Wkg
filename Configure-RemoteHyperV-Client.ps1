# Configure Remote Hyper-V Client in a Workgroup
# Run on FLAMINGO (non-Hyper-V PC) as Administrator

# Step 1: Install Hyper-V Management Tools
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-Tools

# Step 2: Configure Credential Delegation in Registry
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation" `
    -Name AllowFreshCredentials -Value 1 -PropertyType DWord -Force
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentials" `
    -Name 1 -Value "wsman/tomhawk" -PropertyType String -Force

# Step 3: Add Hyper-V host to TrustedHosts
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "tomhawk" -Force

# Step 4: Apply the changes
gpupdate /force

# Step 5: Test WinRM connectivity
Test-WSMan -ComputerName tomhawk