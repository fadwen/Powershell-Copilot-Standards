# WinRM Configuration and Troubleshooting

## WinRM Connection Issues

### Problem
```
Connecting to remote server failed with the following error message: 
WinRM cannot complete the operation.
```

### Prerequisites Check
```powershell
# Test WinRM connectivity
Test-WSMan -ComputerName "SERVER01"

# Check WinRM service status
Get-Service WinRM -ComputerName "SERVER01"
```

### Basic WinRM Setup
```powershell
# On target server (run as Administrator)
Enable-PSRemoting -Force
Set-WSManQuickConfig -Force

# Configure firewall
Enable-NetFirewallRule -DisplayGroup "Windows Remote Management"
```

### Advanced Configuration
```powershell
# Increase memory limits for large operations
Set-WSManInstance -ResourceURI winrm/config/winrs -ValueSet @{MaxMemoryPerShellMB="1024"}

# Set authentication methods
Set-WSManInstance -ResourceURI winrm/config/service/auth -ValueSet @{Basic="true"}
```

## Authentication Issues

### Problem
Access denied errors when connecting remotely

### Solutions
1. **Check User Permissions**
   ```powershell
   # Add user to Remote Management Users group
   Add-LocalGroupMember -Group "Remote Management Users" -Member "DOMAIN\Username"
   ```

2. **Configure Trusted Hosts** (for non-domain scenarios)
   ```powershell
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "SERVER01,SERVER02" -Force
   ```

3. **Use Credential Delegation**
   ```powershell
   # Enable CredSSP for multi-hop scenarios
   Enable-WSManCredSSP -Role Client -DelegateComputer "*.contoso.com"
   Enable-WSManCredSSP -Role Server
   ```
