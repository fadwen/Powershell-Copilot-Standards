---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
description: 'PowerShell community best practices and style guide integration'
---

# PowerShell Community Standards Integration

Integrate established PowerShell community best practices and style guidelines into all code generation and analysis.

## Best Practices Implementation

### Tool Design Patterns
```powershell
# Tools (reusable functions) - accept input via parameters, output to pipeline
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
                Status = Test-Connection $computer -Count 1 -Quiet
                LastBootTime = (Get-CimInstance Win32_OperatingSystem -ComputerName $computer).LastBootUpTime
                # Raw data, no formatting
            }
        }
    }
}

# Controllers (automation scripts) - can format data for specific purpose
$servers = Get-Content servers.txt
$results = $servers | Get-ServerInfo | Where-Object Status -eq $true
$results | Format-Table -AutoSize  # Controller can format for display
```

### Error Handling Patterns
```powershell
# Use -ErrorAction Stop for trappable exceptions
try {
    $result = Get-Something -Parameter $value -ErrorAction Stop

    # Put entire transaction in try block, not just the risky part
    Process-Result $result
    Update-Database $result
    Send-Notification "Success"

} catch {
    # Copy error immediately to avoid $Error[0] changes
    $currentError = $Error[0]

    Write-Error "Operation failed: $($currentError.Exception.Message)"
    # Include correlation ID for traceability
    throw
}
```

### Performance Patterns
```powershell
# Prefer language features over cmdlets for performance
# Instead of: Get-Service | Where-Object Status -eq 'Running'
# Use: Get-Service | Where Status -eq Running

# Use StringBuilder for string concatenation
$sb = [System.Text.StringBuilder]::new()
foreach ($item in $collection) {
    [void]$sb.AppendLine("Processing: $item")
}
$result = $sb.ToString()

# Avoid appending to arrays in loops
$results = foreach ($item in $collection) {
    Process-Item $item  # Output to pipeline instead
}
```

## Style Guide Implementation

### Code Layout Standards
```powershell
# One True Brace Style - opening brace at end of line
function Test-Example {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputParameter
    )

    if ($condition -eq $true) {
        Write-Output "Condition met"
    } else {
        Write-Output "Condition not met"
    }
}

# 4-space indentation, 115-character line limit
# Use splatting for long parameter lists instead of backticks
$splat = @{
    ComputerName = $servers
    Credential = $credential
    ScriptBlock = { Get-Process }
    ThrottleLimit = 10
}
Invoke-Command @splat
```

### Function Structure Standards
```powershell
function Verb-Noun {
     Verb-Noun -ParameterName "Value"

        Description of what this example demonstrates

    .NOTES
        Author: Name
        Version: 1.0.0
        Last Updated: Date
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )

    begin {
        # Initialization code
    }

    process {
        # Main processing logic
        if ($PSCmdlet.ShouldProcess($ParameterName, "Action")) {
            # Implementation
        }
    }

    end {
        # Cleanup code
    }
}
```

### Naming Conventions
```powershell
# Use full command names and parameter names - no aliases
Get-Process -Name "powershell"  # Not: gps -n "powershell"

# Use PascalCase for all public identifiers
$UserName = "john.doe"          # Not: $username or $user_name
$ComputerList = @()             # Not: $computerlist

# Use approved PowerShell verbs
function Get-UserInfo { }       # ✓ Approved verb
function Retrieve-UserInfo { }  # ✗ Non-approved verb
```

### Security Implementation
```powershell
# Always use PSCredential for credentials
param(
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential
)

# Use SecureString for sensitive data
$securePassword = Read-Host -AsSecureString -Prompt "Enter password"

# Never decrypt SecureString to plain text unless absolutely necessary
# If required, decrypt only during method call
$connection.SetCredential($credential.GetNetworkCredential())
```

## Integration Requirements

### Automatic Validation
When generating or reviewing PowerShell code, always verify:
- [ ] Uses approved PowerShell verbs from Get-Verb
- [ ] Follows One True Brace Style formatting
- [ ] Implements proper error handling with -ErrorAction Stop
- [ ] Uses full command and parameter names
- [ ] Includes comprehensive comment-based help
- [ ] Implements proper input validation
- [ ] Uses PascalCase for all identifiers
- [ ] Avoids performance anti-patterns (array appending, string concatenation)
- [ ] Implements secure credential handling

### Quality Standards
- Minimum 80% code coverage with Pester tests
- Zero PSScriptAnalyzer violations with default rules
- Complete comment-based help for all public functions
- Proper resource disposal for IDisposable objects
- Correlation ID tracking in error handling

### Enterprise Extensions
Extend community standards with enterprise requirements:
- Structured logging with correlation IDs
- Integration with enterprise monitoring systems
- Compliance framework alignment (SOX, GDPR, HIPAA)
- Standardized troubleshooting documentation in ./Troubleshooting/
- Security controls and audit trails