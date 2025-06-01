# Server Monitoring Performance Issues

## Slow Performance Monitoring

### Problem
Server health checks taking too long to complete

### Diagnostic Steps
```powershell
# Measure execution time
Measure-Command {
    Get-ServerHealth -ComputerName $servers
}

# Profile individual components
Measure-Command { Test-Connection $server }
Measure-Command { Get-CimInstance Win32_OperatingSystem -ComputerName $server }
```

### Optimization Strategies

#### 1. Parallel Processing
```powershell
# PowerShell 7+ parallel processing
$servers | ForEach-Object -Parallel {
    Get-ServerHealth -ComputerName $_
} -ThrottleLimit 10
```

#### 2. Batch Processing
```powershell
# Process servers in smaller batches
$serverBatches = $servers | Group-Object {[math]::Floor($_.ReadCount / 10)}
foreach ($batch in $serverBatches) {
    $batch.Group | Get-ServerHealth
    Start-Sleep -Seconds 5  # Prevent overwhelming network
}
```

#### 3. Optimize WMI/CIM Queries
```powershell
# Use CIM instead of WMI for better performance
Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $servers

# Use specific properties only
Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime -ComputerName $servers
```

## Memory Usage Issues

### Problem
PowerShell consuming excessive memory during monitoring

### Solutions
1. **Dispose of Objects**
   ```powershell
   try {
       $session = New-CimSession -ComputerName $server
       Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem
   }
   finally {
       if ($session) { Remove-CimSession $session }
   }
   ```

2. **Use Streaming Output**
   ```powershell
   # Stream results instead of collecting all in memory
   $servers | ForEach-Object {
       Get-ServerHealth -ComputerName $_
   } | Export-Csv "results.csv" -NoTypeInformation
   ```
