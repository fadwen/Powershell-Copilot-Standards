# PowerShell Community Best Practices

This document consolidates established PowerShell community best practices that are automatically enforced through our GitHub Copilot instructions.

## 🏗️ Tool vs Controller Design

### Tools (Reusable Functions)
**Purpose**: Create reusable functions that can be used in multiple scenarios

**Characteristics**:
- Accept input via parameters
- Output raw data to the pipeline
- High level of reusability
- No formatting or display logic

```powershell
# Good: Tool function
function Get-ServerInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$ComputerName
    )
    
    process {
        foreach ($computer in $ComputerName) {
            # Return raw data for maximum reusability
            [PSCustomObject]@{
                ComputerName = $computer
                CPUUsage = (Get-Counter "\Processor(_Total)\% Processor Time" -ComputerName $computer).CounterSamples.CookedValue
                MemoryUsage = (Get-Counter "\Memory\Available MBytes" -ComputerName $computer).CounterSamples.CookedValue
                LastBootTime = (Get-CimInstance Win32_OperatingSystem -ComputerName $computer).LastBootUpTime
            }
        }
    }
}
```

### Controllers (Automation Scripts)
**Purpose**: Automate specific business processes using tools and commands

**Characteristics**:
- Use tools to accomplish specific tasks
- May format data for display or reporting
- Not intended for reuse
- Focus on automating business processes

```powershell
# Good: Controller script
# Get server list and generate formatted report
$servers = Get-Content "servers.txt"
$healthData = $servers | Get-ServerInfo

# Controllers can format data for specific purposes
$healthData | 
    Where-Object CPUUsage -lt 80 |
    Format-Table ComputerName, 
                 @{Name="CPU%";Expression={"{0:N1}" -f $_.CPUUsage}},
                 @{Name="Memory GB";Expression={"{0:N1}" -f ($_.MemoryUsage/1024)}} -AutoSize
```

## ⚠️ Error Handling Best Practices

### Use -ErrorAction Stop for Trappable Exceptions
```powershell
try {
    # Use -ErrorAction Stop to generate terminating exceptions
    $result = Get-Something -Parameter $value -ErrorAction Stop
    
    # Put entire "transaction" in try block
    Process-Result $result
    Update-Database $result
    Send-Notification "Success"
    
} catch {
    # Immediately copy error to avoid $Error[0] changes
    $currentError = $Error[0]
    
    Write-Error "Operation failed: $($currentError.Exception.Message)"
    throw
}
```

### Avoid Error Handling Anti-Patterns
```powershell
# ❌ Don't use flags for error handling
try {
    $continue = $true
    Do-Something -ErrorAction Stop
} catch {
    $continue = $false
}
if ($continue) { Do-Other-Things }

# ❌ Don't use $? for error detection
Do-Something
if (-not $?) { Write-Error "Something failed" }

# ❌ Don't test null variables as error conditions
$user = Get-ADUser -Identity DonJ
if ($user) { 
    $user | Do-Something 
} else { 
    Write-Warning "Could not get user" 
}
```

## 🚀 Performance Best Practices

### Language Features Over Cmdlets
```powershell
# ✅ Preferred - language features are faster
Get-Service | Where Status -eq Running

# ❌ Slower - traditional syntax
Get-Service | Where-Object { $_.Status -eq 'Running' }
```

### Avoid Array Appending in Loops
```powershell
# ❌ Slow - array recreation on each iteration
$results = @()
foreach ($item in $collection) {
    $results += Process-Item $item
}

# ✅ Fast - pipeline output
$results = foreach ($item in $collection) {
    Process-Item $item  # Output directly to pipeline
}

# ✅ Also fast - collect at end
$results = $collection | ForEach-Object { Process-Item $_ }
```

### String Concatenation Optimization
```powershell
# ❌ Slow - string concatenation in loops
$output = ""
foreach ($item in $collection) {
    $output += "Processing: $item`n"
}

# ✅ Fast - StringBuilder
$sb = [System.Text.StringBuilder]::new()
foreach ($item in $collection) {
    [void]$sb.AppendLine("Processing: $item")
}
$output = $sb.ToString()
```

## 🔒 Security Best Practices

### Always Use PSCredential
```powershell
# ✅ Correct credential handling
param(
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential
)

# Use credential without exposing password
Invoke-Command -ComputerName $server -Credential $Credential -ScriptBlock { Get-Process }
```

### SecureString for Sensitive Data
```powershell
# ✅ Secure password collection
$securePassword = Read-Host -AsSecureString -Prompt "Enter password"

# ✅ Secure credential creation
$credential = New-Object PSCredential($username, $securePassword)

# ✅ If you must decrypt (rare), do it only during method call
$connection.SetPassword($credential.GetNetworkCredential().Password)
```

### Input Validation
```powershell
# ✅ Comprehensive parameter validation
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9\-\.]+$')]
    [ValidateLength(1, 255)]
    [string]$ComputerName,
    
    [Parameter()]
    [ValidateRange(1, 100)]
    [int]$Threshold = 80
)
```

## 🎨 Style and Formatting

### One True Brace Style
```powershell
# ✅ Correct brace placement
function Test-Function {
    [CmdletBinding()]
    param(
        [string]$Parameter
    )
    
    if ($condition -eq $true) {
        Write-Output "Condition met"
    } else {
        Write-Output "Condition not met"
    }
}
```

### Use Splatting Instead of Backticks
```powershell
# ❌ Avoid backticks for line continuation
Get-WmiObject -Class Win32_LogicalDisk `
              -Filter "DriveType=3" `
              -ComputerName $server

# ✅ Use splatting instead
$params = @{
    Class = 'Win32_LogicalDisk'
    Filter = 'DriveType=3'
    ComputerName = $server
}
Get-WmiObject @params
```

### Proper Output Methods
```powershell
# ❌ Avoid Write-Host (unless colored output needed)
Write-Host "Processing complete"

# ✅ Use appropriate output streams
Write-Output "Data for pipeline"        # For data
Write-Verbose "Detailed information"    # For details
Write-Information "User information"    # For user messages
Write-Warning "Potential issues"        # For warnings
Write-Error "Error occurred"           # For errors
```

## 📝 Documentation Standards

### Complete Comment-Based Help
```powershell
function Get-ServerHealth {
     Get-ServerHealth -ComputerName "SERVER01"
        
        DESCRIPTION: Basic health check for single server
        OUTPUT: Health metrics object with CPU, memory, and disk data
        USE CASE: Daily server monitoring during morning checks
    
    .EXAMPLE
        PS> "WEB01", "WEB02" | Get-ServerHealth | Where-Object CPUUsage -gt 80
        
        DESCRIPTION: Pipeline processing with filtering for high CPU usage
        OUTPUT: Only servers with CPU usage above 80%
        USE CASE: Automated alerting for performance issues
    
    .NOTES
        Author: Your Name
        Version: 1.0.0
        Last Updated: 2024-01-15
        
        TROUBLESHOOTING:
        - Connectivity issues: .\Troubleshooting\Connectivity\WinRM-Setup.md
        - Performance problems: .\Troubleshooting\Performance\Server-Monitoring.md
    #>
    
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ComputerName
    )
    
    # Implementation here...
}
```

## 📋 Implementation Checklist

When writing PowerShell code, ensure:

### Function Design
- [ ] Uses approved PowerShell verbs (`Get-Verb`)
- [ ] Follows Verb-Noun naming convention
- [ ] Includes `[CmdletBinding()]` attribute
- [ ] Supports pipeline input where appropriate
- [ ] Returns objects, not formatted text

### Error Handling
- [ ] Uses `-ErrorAction Stop` for trappable exceptions
- [ ] Implements try/catch blocks for transactions
- [ ] Includes correlation IDs for tracking
- [ ] Avoids error flags and null testing

### Performance
- [ ] Uses language features over cmdlets when faster
- [ ] Avoids array appending in loops
- [ ] Uses StringBuilder for string concatenation
- [ ] Implements efficient pipeline processing

### Security
- [ ] Uses PSCredential for all authentication
- [ ] Implements comprehensive input validation
- [ ] Sanitizes all user inputs
- [ ] Logs security-relevant events

### Style and Format
- [ ] Follows One True Brace Style
- [ ] Uses 4-space indentation
- [ ] Keeps lines under 115 characters
- [ ] Uses splatting instead of backticks
- [ ] Uses appropriate output streams

### Documentation
- [ ] Includes complete comment-based help
- [ ] Documents all parameters with examples
- [ ] Provides multiple usage examples
- [ ] References troubleshooting documentation

This document serves as the foundation for all PowerShell development in our organization and is automatically enforced through GitHub Copilot instructions.

---
