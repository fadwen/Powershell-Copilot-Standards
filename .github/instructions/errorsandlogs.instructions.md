---
mode: 'agent'
applyTo: "**/*.ps1,**/*.psm1"
tools: ['codebase', 'githubRepo']
description: 'Implements comprehensive error handling and structured logging for PowerShell solutions'
---

# PowerShell Error Handling and Logging Implementation

Implement robust error handling and structured logging patterns for PowerShell code that ensure proper error management, correlation tracking, and enterprise-grade diagnostic capabilities.

## Error Handling Implementation

### Comprehensive Error Handling Pattern
Generate error handling code following this enterprise pattern:

```powershell
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputParameter
    )

    # Initialize correlation tracking
    $correlationId = [System.Guid]::NewGuid()
    $ErrorActionPreference = 'Stop'

    try {
        Write-Verbose "Starting operation - CorrelationId: $correlationId"

        # Main operation logic here
        $result = Invoke-Operation -CorrelationId $correlationId

        Write-Verbose "Operation completed successfully - CorrelationId: $correlationId"
        return $result
    }
    catch {
        # Structured error logging
        $errorDetails = @{
            CorrelationId = $correlationId
            Function = $MyInvocation.MyCommand.Name
            ErrorMessage = $_.Exception.Message
            StackTrace = $_.ScriptStackTrace
            Timestamp = Get-Date
            InputParameters = $PSBoundParameters
        }

        Write-Error "Operation failed: $($_.Exception.Message) - CorrelationId: $correlationId"

        # Log to troubleshooting system
        $errorDetails | ConvertTo-Json | Out-File ".\Troubleshooting\Logs\error-$correlationId.json"

        throw
    }
    finally {
        # Resource cleanup
        if ($resource -and $resource -is [System.IDisposable]) {
            $resource.Dispose()
        }
    }
}
```

### Custom Exception Classes
Implement custom exception hierarchies for specific error scenarios:

```powershell
# Base exception class
class BaseModuleException : System.Exception {
    [string]$CorrelationId
    [string]$Component
    [string]$Operation
    [hashtable]$Context

    BaseModuleException([string]$Message, [string]$Component, [string]$Operation) : base($Message) {
        $this.CorrelationId = [System.Guid]::NewGuid().ToString()
        $this.Component = $Component
        $this.Operation = $Operation
        $this.Context = @{}
    }

    [void] AddContext([string]$Key, [object]$Value) {
        $this.Context[$Key] = $Value
    }
}

# Specific exception types
class ValidationException : BaseModuleException {
    [string]$ParameterName
    [object]$ParameterValue

    ValidationException([string]$Message, [string]$ParameterName, [object]$ParameterValue) : base($Message, 'Validation', 'ParameterValidation') {
        $this.ParameterName = $ParameterName
        $this.ParameterValue = $ParameterValue
    }
}
```

## Structured Logging Implementation

### PSFramework Integration
Set up comprehensive logging with PSFramework:

```powershell
#requires -Module PSFramework

# Initialize logging configuration
function Initialize-ModuleLogging {
    param(
        [string]$ModuleName = $MyInvocation.MyCommand.Module.Name,
        [string]$LogLevel = 'Information',
        [string]$LogPath = ".\Logs"
    )

    # Configure file logging
    $fileLogPath = Join-Path $LogPath "$ModuleName-{0:yyyy-MM-dd}.log"
    Set-PSFLoggingProvider -Name logfile -FilePath $fileLogPath -Enabled $true

    # Configure console logging
    Set-PSFLoggingProvider -Name console -Enabled $true

    # Set logging level
    Set-PSFConfig -FullName 'psframework.logging.maximumloglevel' -Value $LogLevel

    Write-PSFMessage -Level Host -Message "Logging initialized for module: $ModuleName"
}
```

### Structured Logging Patterns
Implement consistent logging patterns throughout the code:

```powershell
function Write-StructuredLog {
    param(
        [ValidateSet('Critical', 'Error', 'Warning', 'Information', 'Debug', 'Verbose')]
        [string]$Level,
        [string]$Message,
        [string]$Component = 'Unknown',
        [string]$Operation = 'Unknown',
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString(),
        [hashtable]$Data = @{},
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    # Build comprehensive log context
    $logContext = @{
        Component = $Component
        Operation = $Operation
        CorrelationId = $CorrelationId
        MachineName = $env:COMPUTERNAME
        UserName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
    }

    # Add custom data
    foreach ($key in $Data.Keys) {
        $logContext["Data.$key"] = $Data[$key]
    }

    # Add error information if present
    if ($ErrorRecord) {
        $logContext.ErrorType = $ErrorRecord.Exception.GetType().Name
        $logContext.ErrorMessage = $ErrorRecord.Exception.Message
        $logContext.ErrorStackTrace = $ErrorRecord.ScriptStackTrace
    }

    # Write using PSFramework
    Write-PSFMessage -Level $Level -Message $Message -Data $logContext -ErrorRecord $ErrorRecord
}
```

## Security Event Logging

### Security-Specific Logging
Implement specialized logging for security events:

```powershell
function Write-SecurityLog {
    param(
        [ValidateSet('Authentication', 'Authorization', 'DataAccess', 'ConfigurationChange', 'SecurityViolation')]
        [string]$SecurityEventType,
        [string]$Message,
        [ValidateSet('Success', 'Failure', 'Attempt')]
        [string]$Outcome = 'Attempt',
        [string]$TargetResource,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString(),
        [hashtable]$SecurityContext = @{},
        [string]$RiskLevel = 'Medium'
    )

    # Build security context (sanitize sensitive data)
    $securityData = @{
        SecurityEventType = $SecurityEventType
        Outcome = $Outcome
        TargetResource = $TargetResource
        RiskLevel = $RiskLevel
        UserContext = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        SessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    }

    # Add sanitized security context
    foreach ($key in $SecurityContext.Keys) {
        if ($key -notmatch '(password|secret|key|token|credential)') {
            $securityData["Context.$key"] = $SecurityContext[$key]
        }
    }

    # Determine log level based on outcome and event type
    $logLevel = switch ($Outcome) {
        'Failure' { if ($SecurityEventType -in @('Authentication', 'Authorization', 'SecurityViolation')) { 'Error' } else { 'Warning' } }
        'Success' { if ($SecurityEventType -eq 'SecurityViolation') { 'Warning' } else { 'Information' } }
        default { 'Information' }
    }

    Write-StructuredLog -Level $logLevel -Message $Message -Component 'Security' -Operation $SecurityEventType -CorrelationId $CorrelationId -Data $securityData
}
```

## Performance and Correlation Tracking

### Performance Logging
Track performance metrics with structured logging:

```powershell
function Measure-OperationPerformance {
    param(
        [ScriptBlock]$Operation,
        [string]$OperationName,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString(),
        [hashtable]$Metrics = @{}
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $memoryBefore = [System.GC]::GetTotalMemory($false)

    try {
        Write-StructuredLog -Level Debug -Message "Starting performance measurement" -Component 'Performance' -Operation $OperationName -CorrelationId $CorrelationId

        $result = & $Operation

        $stopwatch.Stop()
        $memoryAfter = [System.GC]::GetTotalMemory($false)

        # Calculate performance metrics
        $performanceData = @{
            Duration = $stopwatch.Elapsed.TotalMilliseconds
            MemoryUsed = $memoryAfter - $memoryBefore
            MemoryUsedMB = [math]::Round(($memoryAfter - $memoryBefore) / 1MB, 2)
        }

        # Add custom metrics
        foreach ($key in $Metrics.Keys) {
            $performanceData["Metric.$key"] = $Metrics[$key]
        }

        Write-StructuredLog -Level Information -Message "Performance measurement completed" -Component 'Performance' -Operation $OperationName -CorrelationId $CorrelationId -Data $performanceData

        return $result
    }
    catch {
        $stopwatch.Stop()
        Write-StructuredLog -Level Error -Message "Performance measurement failed" -Component 'Performance' -Operation $OperationName -CorrelationId $CorrelationId -ErrorRecord $_
        throw
    }
}
```

### Correlation ID Management
Implement correlation tracking throughout the application:

```powershell
# Global correlation context
$script:CorrelationContext = @{}

function Start-Operation {
    param(
        [string]$OperationName,
        [string]$ParentCorrelationId
    )

    $correlationId = [System.Guid]::NewGuid().ToString()

    $script:CorrelationContext[$correlationId] = @{
        OperationName = $OperationName
        StartTime = Get-Date
        ParentCorrelationId = $ParentCorrelationId
    }

    Write-StructuredLog -Level Information -Message "Operation started" -Component 'OperationManager' -Operation $OperationName -CorrelationId $correlationId

    return $correlationId
}

function Complete-Operation {
    param(
        [string]$CorrelationId,
        [switch]$Success
    )

    if ($script:CorrelationContext.ContainsKey($CorrelationId)) {
        $context = $script:CorrelationContext[$CorrelationId]
        $duration = (Get-Date) - $context.StartTime

        $operationData = @{
            Duration = $duration.TotalMilliseconds
            Success = $Success.IsPresent
        }

        Write-StructuredLog -Level Information -Message "Operation completed" -Component 'OperationManager' -Operation $context.OperationName -CorrelationId $CorrelationId -Data $operationData

        $script:CorrelationContext.Remove($CorrelationId)
    }
}
```

## Diagnostic and Troubleshooting Support

### Diagnostic Data Export
Generate comprehensive diagnostic information:

```powershell
function Export-DiagnosticData {
    param(
        [string]$OutputPath = ".\Troubleshooting\Diagnostics",
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString(),
        [int]$LogHistoryHours = 24
    )

    # Create diagnostic package
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $diagnosticPath = Join-Path $OutputPath "Diagnostic-$timestamp"
    New-Item -Path $diagnosticPath -ItemType Directory -Force

    # Collect system information
    $diagnosticData = @{
        SystemInfo = Get-ComputerInfo | Select-Object WindowsVersion, TotalPhysicalMemory
        PowerShellInfo = $PSVersionTable
        ModuleInfo = Get-Module | Select-Object Name, Version
        RecentErrors = Get-PSFMessage | Where-Object Level -in @('Error', 'Critical') | Where-Object Timestamp -gt (Get-Date).AddHours(-$LogHistoryHours)
        PerformanceCounters = Get-Counter '\Process(powershell)\Working Set' -ErrorAction SilentlyContinue
    }

    # Export diagnostic data
    $diagnosticData | ConvertTo-Json -Depth 10 | Out-File "$diagnosticPath\diagnostic-data.json"

    Write-StructuredLog -Level Information -Message "Diagnostic data exported" -Component 'Diagnostics' -Operation 'Export' -CorrelationId $CorrelationId -Data @{
        OutputPath = $diagnosticPath
        DataPoints = $diagnosticData.Keys.Count
    }

    return $diagnosticPath
}
```

## Implementation Requirements

When implementing error handling and logging:

### Required Components
1. **Correlation ID tracking** throughout all operations
2. **Structured logging** with consistent format and context
3. **Custom exception classes** for specific error scenarios
4. **Performance measurement** for critical operations
5. **Security event logging** for audit and compliance
6. **Diagnostic data collection** for troubleshooting support

### Integration Points
- Reference troubleshooting documentation in `.\Troubleshooting\` folder
- Integrate with enterprise monitoring and alerting systems
- Support compliance and audit requirements
- Enable automated error analysis and trending

### Quality Standards
- All errors must include correlation IDs for traceability
- Security events must be logged with appropriate detail and protection
- Performance metrics must be captured for baseline establishment
- Diagnostic data must be comprehensive enough for remote troubleshooting

Generate error handling and logging implementations that follow these enterprise patterns while maintaining consistency with the established PowerShell development standards and troubleshooting documentation structure.