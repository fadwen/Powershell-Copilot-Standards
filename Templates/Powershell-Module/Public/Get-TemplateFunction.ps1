function Get-TemplateFunction {
    <#
    .SYNOPSIS
    Template function demonstrating enterprise PowerShell standards.

    .DESCRIPTION
    This template function showcases modern PowerShell best practices including
    proper error handling, parameter validation, configuration usage, and
    enterprise logging patterns. Use this as a starting point for new functions.

    .PARAMETER ServiceName
    The name of the service to query or process.

    .PARAMETER EnvironmentType
    The target environment for the operation.

    .PARAMETER IncludeMetrics
    When specified, includes performance metrics in the output.

    .EXAMPLE
    Get-TemplateFunction -ServiceName "UserService" -EnvironmentType "Production"

    Processes the UserService for production environment with default settings.

    .EXAMPLE
    Get-TemplateFunction -ServiceName "DataService" -EnvironmentType "Development" -IncludeMetrics

    Processes the DataService for development environment including performance metrics.

    .OUTPUTS
    ServiceProcessingResult. Returns processing results with status and data.
    #>
    [CmdletBinding()]
    [OutputType([ServiceProcessingResult])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$ServiceName,

        [Parameter()]
        [ValidateSet('Development', 'Testing', 'Production')]
        [string]$EnvironmentType = 'Development',

        [Parameter()]
        [switch]$IncludeMetrics,

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-Verbose "Starting template function processing - CorrelationId: $CorrelationId"

        # Load environment-specific configuration
        $config = Get-EnvironmentConfiguration -Environment $EnvironmentType

        # Initialize performance tracking if requested
        if ($IncludeMetrics) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }
    }

    process {
        try {
            # Validate service name parameter before using in function calls
            if (-not $ServiceName.Trim()) {
                Write-Error "ServiceName cannot be empty or whitespace" -ErrorAction Stop
                return
            }

            # Use ServiceName in service validation
            if (-not (Test-ServiceConnection -ServiceName $ServiceName.Trim() -Timeout $config.ConnectionTimeout)) {
                Write-Error "Service '$ServiceName' is not available or not responding" -ErrorAction Stop
                return
            }

            # Process based on environment configuration using all parameters
            $processingOptions = @{
                ServiceName = $ServiceName.Trim()
                Environment = $EnvironmentType
                AuditLevel = $config.AuditLevel
                RetryCount = $config.RetryCount
                CorrelationId = $CorrelationId
            }

            Write-Verbose "Processing service '$ServiceName' in '$EnvironmentType' environment - CorrelationId: $CorrelationId"

            # Simulate service processing with configuration-driven behavior
            $serviceData = Invoke-ServiceProcessing @processingOptions

            # Apply environment-specific transformations using EnvironmentType
            $transformedData = switch ($EnvironmentType) {
                'Production' {
                    # Production: Full validation and security checks
                    $serviceData | Add-Member -MemberType NoteProperty -Name "SecurityValidated" -Value $true -PassThru |
                    Add-Member -MemberType NoteProperty -Name "ComplianceChecked" -Value $true -PassThru
                }
                'Testing' {
                    # Testing: Add debug information and validation
                    $serviceData | Add-Member -MemberType NoteProperty -Name "TestingMetadata" -Value @{Environment = $EnvironmentType; DebugMode = $true} -PassThru |
                    Add-Member -MemberType NoteProperty -Name "ValidationResults" -Value "Passed" -PassThru
                }
                'Development' {
                    # Development: Add extensive debugging information
                    $serviceData | Add-Member -MemberType NoteProperty -Name "DebugInfo" -Value @{Environment = $EnvironmentType; VerboseLogging = $true} -PassThru |
                    Add-Member -MemberType NoteProperty -Name "DeveloperNotes" -Value "Enhanced logging enabled" -PassThru
                }
            }

            # Create result object using all parameters
            $result = [PSCustomObject]@{
                PSTypeName = 'ServiceProcessingResult'
                Status = "Success"
                ServiceName = $ServiceName.Trim()
                Environment = $EnvironmentType
                Data = $transformedData
                ProcessingTime = if ($IncludeMetrics -and $stopwatch) { $stopwatch.Elapsed } else { $null }
                CorrelationId = $CorrelationId
                Timestamp = Get-Date
                ConfigurationApplied = @{
                    AuditLevel = $config.AuditLevel
                    RetryCount = $config.RetryCount
                    Timeout = $config.ConnectionTimeout
                    Environment = $EnvironmentType
                }
            }

            # Performance validation based on environment using metrics
            if ($IncludeMetrics -and $stopwatch -and $stopwatch.ElapsedMilliseconds -gt $config.PerformanceThreshold) {
                Write-Warning "Processing of '$ServiceName' exceeded performance threshold in '$EnvironmentType' environment - Elapsed: $($stopwatch.ElapsedMilliseconds)ms, Threshold: $($config.PerformanceThreshold)ms - CorrelationId: $CorrelationId"
                $result | Add-Member -MemberType NoteProperty -Name "PerformanceWarning" -Value $true
            }

            Write-Output $result
        }
        catch {
            # Modern error handling using $_ instead of $Error[0]
            $errorDetails = @{
                ServiceName = $ServiceName.Trim()
                Environment = $EnvironmentType
                ErrorMessage = $_.Exception.Message
                ErrorCategory = $_.CategoryInfo.Category.ToString()
                ScriptLineNumber = $_.InvocationInfo.ScriptLineNumber
                CorrelationId = $CorrelationId
            }

            Write-Verbose "Template function processing failed for '$ServiceName' in '$EnvironmentType' - CorrelationId: $CorrelationId - Error: $($_.Exception.Message)"

            # Environment-appropriate error handling
            if ($EnvironmentType -eq "Production") {
                # Production: Re-throw to preserve stack trace
                Write-Error "Production processing failed for service '$ServiceName': $($_.Exception.Message)" -ErrorAction Stop
            } else {
                # Development/Testing: Return error details for debugging
                $errorResult = [PSCustomObject]@{
                    PSTypeName = 'ServiceProcessingResult'
                    Status = "Error"
                    ServiceName = $ServiceName.Trim()
                    Environment = $EnvironmentType
                    ErrorDetails = $errorDetails
                    CorrelationId = $CorrelationId
                    Timestamp = Get-Date
                }

                Write-Output $errorResult
            }
        }
    }

    end {
        if ($IncludeMetrics -and $stopwatch) {
            $stopwatch.Stop()
            Write-Verbose "Template function processing completed for '$ServiceName' in '$EnvironmentType' - Total time: $($stopwatch.ElapsedMilliseconds)ms - CorrelationId: $CorrelationId"
        } else {
            Write-Verbose "Template function processing completed for '$ServiceName' in '$EnvironmentType' - CorrelationId: $CorrelationId"
        }
    }
}

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