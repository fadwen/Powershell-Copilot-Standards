<#
    Internal helpers for Get-TemplateFunction.

    These live in Private/ because the manifest does not export them: callers
    depend on Get-TemplateFunction, so these can change shape without a
    breaking release. They previously sat in Public/Get-TemplateFunction.ps1,
    placing internal helpers in the folder reserved for public surface.
#>

# Supporting functions for the template (simplified implementations)
function Get-EnvironmentConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Testing', 'Production')]
        [string]$Environment
    )

    $configurations = @{
        'Development' = @{
            Environment = 'Development'
            AuditLevel = 'Verbose'
            ConnectionTimeout = 30
            RetryCount = 3
            PerformanceThreshold = 5000
        }
        'Testing' = @{
            Environment = 'Testing'
            AuditLevel = 'Standard'
            ConnectionTimeout = 15
            RetryCount = 2
            PerformanceThreshold = 3000
        }
        'Production' = @{
            Environment = 'Production'
            AuditLevel = 'Minimal'
            ConnectionTimeout = 10
            RetryCount = 1
            PerformanceThreshold = 1000
        }
    }

    return [PSCustomObject]$configurations[$Environment]
}

function Test-ServiceConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter()]
        [int]$Timeout = 30
    )

    # Simulate service connection test using both parameters
    Write-Verbose "Testing connection to service '$ServiceName' with timeout of $Timeout seconds"
    Start-Sleep -Milliseconds 100
    return $true
}

function Invoke-ServiceProcessing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter()]
        [string]$Environment,

        [Parameter()]
        [string]$AuditLevel,

        [Parameter()]
        [int]$RetryCount,

        [Parameter()]
        [string]$CorrelationId
    )

    # Simulate service processing using all parameters
    Write-Verbose "Processing service '$ServiceName' in '$Environment' with audit level '$AuditLevel', retry count $RetryCount - CorrelationId: $CorrelationId"

    return @{
        ServiceId = [System.Guid]::NewGuid().ToString()
        ProcessedAt = Get-Date
        Status = "Processed"
        Records = 150
        Environment = $Environment
        AuditLevel = $AuditLevel
        RetriesUsed = 0
        MaxRetries = $RetryCount
        CorrelationId = $CorrelationId
    }
}
