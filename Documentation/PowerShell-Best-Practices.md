# PowerShell Best Practices

## 🎯 Core Principles

### Error Handling

#### Modern Error Handling
```powershell
try {
    $result = Invoke-Operation -Parameter $value
}
catch {
    # ✅ Use $_ for current error - cleaner and more direct
    $errorMessage = $_.Exception.Message
    $errorLine = $_.InvocationInfo.ScriptLineNumber

    Write-EnterpriseLog -Level "ERROR" -Message "Operation failed: $errorMessage" -Line $errorLine
    throw $_ # Re-throw to preserve stack trace
}
```

#### Context-Appropriate Null Handling
```powershell
# ✅ Simple null check for existence testing (efficient)
if ($null -eq $configValue) {
    $configValue = Get-DefaultConfiguration
}

# ✅ Exception handling for operations that genuinely might fail
try {
    $data = Get-RemoteData -Url $url -ErrorAction Stop
}
catch {
    Write-Warning "Remote data unavailable, using cached version"
    $data = Get-CachedData
}
```

### String Operations

#### Small Operations - Simple Concatenation
```powershell
# ✅ For simple, small concatenations (under ~100 operations)
$message = "Error in function " + $functionName + " at line " + $lineNumber
$fullPath = $basePath + "\" + $fileName + "." + $extension
```

#### Large Operations - StringBuilder
```powershell
# ✅ For large collections or repeated operations
$sb = [System.Text.StringBuilder]::new()
foreach ($logEntry in $largeLogs) {
    [void]$sb.AppendLine("$($logEntry.Timestamp): $($logEntry.Message)")
}
$output = $sb.ToString()

# ✅ Alternative: Use -join for collections
$output = $logEntries | ForEach-Object { "$($_.Timestamp): $($_.Message)" } | Out-String
```

### Modern PowerShell Features

#### Credential Creation
```powershell
# ✅ PowerShell 5+ modern approach
$credential = [PSCredential]::new($userName, $securePassword)

# ❌ Legacy approach (still works, but unnecessary)
$credential = New-Object PSCredential($userName, $securePassword)
```

#### Parameter Validation
```powershell
# ✅ Mandatory parameters are implicitly validated
[Parameter(Mandatory)]
[string]$UserName  # No need for ValidateNotNullOrEmpty with Mandatory

# ✅ Use validation attributes where they add value
[Parameter()]
[ValidateSet('Development', 'Testing', 'Production')]
[string]$Environment = 'Development',

[Parameter()]
[ValidateRange(1, 100)]
[int]$RetryCount = 3
```

### Comment-Based Help

```powershell
function Get-UserData {
    <#
    .SYNOPSIS
    Retrieves user data from the enterprise directory.

    .DESCRIPTION
    This function connects to the enterprise directory service and retrieves
    comprehensive user information including profile data, group memberships,
    and access permissions.

    .PARAMETER UserName
    The username to look up in the directory service.

    .PARAMETER IncludeGroups
    When specified, includes group membership information in the output.

    .EXAMPLE
    Get-UserData -UserName "jdoe"

    Retrieves basic user information for user "jdoe".

    .EXAMPLE
    Get-UserData -UserName "jdoe" -IncludeGroups

    Retrieves user information including group memberships.

    .INPUTS
    String. You can pipe usernames to this function.

    .OUTPUTS
    UserInfo. Returns a custom object with user information.
    #>
    [CmdletBinding()]
    [OutputType([UserInfo])] # Use descriptive custom type names
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$UserName,

        [Parameter()]
        [switch]$IncludeGroups
    )
    # Function implementation...
}
```

### Output Types

```powershell
# ✅ Use descriptive type names that provide meaning
[OutputType([UserInfo])]
[OutputType([ConfigurationData])]
[OutputType([ProcessingResult])]

# ✅ Use specific .NET types when appropriate
[OutputType([System.IO.FileInfo])]
[OutputType([System.Collections.Hashtable])]

# ❌ Avoid misleading [PSCustomObject] declarations
# [OutputType([PSCustomObject])] # This doesn't provide useful information

# ✅ For custom objects, define a class or use descriptive names
class ProcessingResult {
    [string]$Status
    [object]$Data
    [datetime]$Timestamp
    [string]$CorrelationId
}

[OutputType([ProcessingResult])]
```

## 🔧 Function Structure - Enhanced Template

```powershell
function Get-EnterpriseData {
    <#
    .SYNOPSIS
    Retrieves enterprise data with comprehensive error handling and logging.

    .DESCRIPTION
    This function demonstrates modern PowerShell best practices including
    proper error handling, parameter validation, and enterprise patterns.

    .PARAMETER DataSource
    The source system to retrieve data from.

    .PARAMETER FilterCriteria
    Optional criteria to filter the retrieved data.

    .EXAMPLE
    Get-EnterpriseData -DataSource "UserDirectory"

    Retrieves all data from the User Directory system.

    .OUTPUTS
    EnterpriseDataResult. Contains the retrieved data and metadata.
    #>
    [CmdletBinding()]
    [OutputType([EnterpriseDataResult])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('UserDirectory', 'AssetDatabase', 'ConfigurationStore')]
        [string]$DataSource,

        [Parameter()]
        [hashtable]$FilterCriteria = @{},

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-EnterpriseLog -Level "INFO" -Message "Starting data retrieval" -CorrelationId $CorrelationId

        # Configuration-driven behavior
        $config = Get-DataSourceConfiguration -Source $DataSource
    }

    process {
        try {
            # Validate connection before processing
            if (-not (Test-DataSourceConnection -Source $DataSource)) {
                throw "Unable to connect to data source: $DataSource"
            }

            # Retrieve data with timeout handling
            $rawData = Invoke-DataRetrieval -Source $DataSource -Filter $FilterCriteria -Timeout $config.TimeoutSeconds

            # Process and enrich data
            $processedData = $rawData | ForEach-Object {
                Add-EnterpriseMetadata -Data $_ -CorrelationId $CorrelationId
            }

            # Create result object
            $result = [EnterpriseDataResult]@{
                Status = "Success"
                Data = $processedData
                Count = $processedData.Count
                Source = $DataSource
                CorrelationId = $CorrelationId
                Timestamp = Get-Date
            }

            Write-Output $result
        }
        catch {
            # ✅ Use $_ for current error
            $errorDetails = @{
                Message = $_.Exception.Message
                Category = $_.CategoryInfo.Category.ToString()
                Source = $DataSource
                CorrelationId = $CorrelationId
                ScriptLineNumber = $_.InvocationInfo.ScriptLineNumber
            }

            Write-EnterpriseLog -Level "ERROR" -Message "Data retrieval failed" -Details $errorDetails

            # Environment-appropriate error handling
            if ($config.Environment -eq "Production") {
                throw $_ # Preserve original exception in production
            } else {
                Write-Warning "Development mode: Returning empty result set"
                return [EnterpriseDataResult]@{
                    Status = "Error"
                    Data = @()
                    Count = 0
                    Source = $DataSource
                    CorrelationId = $CorrelationId
                    Timestamp = Get-Date
                    ErrorMessage = $_.Exception.Message
                }
            }
        }
    }

    end {
        Write-EnterpriseLog -Level "INFO" -Message "Data retrieval completed" -CorrelationId $CorrelationId
    }
}
```

## 🚀 Performance Best Practices - Nuanced Approach

### Collection Operations ✅
```powershell
# ✅ For small collections (< 1000 items), simple approaches work fine
$results = @()
foreach ($item in $smallCollection) {
    $results += Process-Item $item  # Acceptable for small collections
}

# ✅ For large collections, use efficient approaches
$results = [System.Collections.Generic.List[object]]::new()
foreach ($item in $largeCollection) {
    $results.Add((Process-Item $item))
}

# ✅ Best: Use pipeline when possible
$results = $collection | ForEach-Object { Process-Item $_ }
```

### String Building - Context Matters
```powershell
# ✅ Simple concatenation for small operations
$logMessage = $timestamp + " - " + $level + " - " + $message

# ✅ StringBuilder for large or repeated operations
$report = [System.Text.StringBuilder]::new()
foreach ($entry in $logEntries) {
    [void]$report.AppendLine("$($entry.Time): $($entry.Message)")
}

# ✅ Join operator for collections
$csvLine = $dataFields -join ","
$reportText = $logLines -join "`n"
```

## 🛡️ Security Patterns

### Modern Credential Handling
```powershell
# ✅ Modern credential creation
$credential = [PSCredential]::new($userName, $securePassword)

# ✅ Secure parameter handling
param(
    [Parameter(Mandatory)]
    [PSCredential]$Credential,

    [Parameter()]
    [SecureString]$ApiKey
)

# ✅ Convert plain text securely when necessary
$secureString = ConvertTo-SecureString $plainTextPassword -AsPlainText -Force
$credential = [PSCredential]::new($userName, $secureString)
```

### Input Validation
```powershell
# ✅ Use validation where it adds value
param(
    [Parameter(Mandatory)] # Implicit null/empty validation
    [string]$UserName,

    [Parameter()]
    [ValidateSet('Read', 'Write', 'Admin')] # Constrains valid values
    [string]$AccessLevel = 'Read',

    [Parameter()]
    [ValidateScript({ Test-Path $_ })] # Custom validation logic
    [string]$ConfigPath
)
```

## 📊 Enterprise Integration Patterns

### Audit Trail Implementation
```powershell
function Write-EnterpriseLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter()]
        [hashtable]$Details = @{},

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    $logEntry = @{
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
        Level = $Level
        Message = $Message
        CorrelationId = $CorrelationId
        Details = $Details
        User = $env:USERNAME
        Computer = $env:COMPUTERNAME
        Process = $PID
    } | ConvertTo-Json -Compress

    # Write to appropriate log destination based on environment
    $config = Get-LoggingConfiguration
    if ($config.StructuredLogging) {
        Write-Output $logEntry | Out-File -FilePath $config.LogPath -Append -Encoding UTF8
    } else {
        Write-Host "[$Level] $Message" -ForegroundColor $(Get-LogColor $Level)
    }
}
```

## ✅ Updated Quality Checklist

- ✅ Uses approved PowerShell verbs consistently
- ✅ Implements modern error handling with `$_` in catch blocks
- ✅ Uses context-appropriate string operations
- ✅ Leverages modern PowerShell features ([PSCredential]::new(), etc.)
- ✅ Implements balanced parameter validation
- ✅ Uses proper comment-based help format
- ✅ Defines meaningful output types
- ✅ Includes correlation tracking for enterprise scenarios
- ✅ Handles null checks appropriately without forcing exceptions
- ✅ Implements performance patterns appropriate to scale