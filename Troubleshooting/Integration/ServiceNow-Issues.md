# ServiceNow Integration Troubleshooting

## Connection Issues

### Problem
Cannot connect to ServiceNow REST API

### Diagnostic Steps
```powershell
# Test basic connectivity
Test-NetConnection -ComputerName "instance.service-now.com" -Port 443

# Test API endpoint
$uri = "https://instance.service-now.com/api/now/table/change_request"
try {
    Invoke-RestMethod -Uri $uri -Method GET -Credential $credential
} catch {
    Write-Host "Error: $($_.Exception.Message)"
}
```

### Solutions
1. **Verify Credentials**
   ```powershell
   # Test with known good credentials
   $credential = Get-Credential
   $headers = @{
       'Authorization' = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($credential.UserName):$($credential.GetNetworkCredential().Password)"))
   }
   ```

2. **Check SSL/TLS Settings**
   ```powershell
   # Allow TLS 1.2 if required
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   ```

## Change Ticket Validation Issues

### Problem
Change tickets not found or invalid state

### Diagnostic Steps
```powershell
# Check ticket status
$ticket = Get-ServiceNowTicket -Number "CHG0030001"
Write-Host "Ticket State: $($ticket.State)"
Write-Host "Approval Status: $($ticket.Approval)"
```

### Solutions
1. **Validate Ticket Format**
   ```powershell
   # Ensure correct format
   if ($ChangeTicket -notmatch '^CHG\d{7}$') {
       throw "Invalid change ticket format. Expected: CHG0000000"
   }
   ```

2. **Check Approval Workflow**
   ```powershell
   # Verify ticket is in approved state
   $validStates = @('Approved', 'Scheduled', 'Work In Progress')
   if ($ticket.State -notin $validStates) {
       throw "Change ticket $ChangeTicket is not in valid state for implementation"
   }
   ```
