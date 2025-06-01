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
        Write-EnterpriseLog -Level "INFO" -Message "Starting template function processing" -CorrelationId $CorrelationId

        # Load environment-specific configuration
        $config = Get-EnvironmentConfiguration -Environment $EnvironmentType

        # Initialize performance tracking if requested
        if ($IncludeMetrics) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        }
    }

    process {
        try {
            # Validate service availability
            if (-not (Test-ServiceConnection -ServiceName $ServiceName -Timeout $config.ConnectionTimeout)) {
                throw "Service '$ServiceName' is not available or not responding"
            }

            # Process based on environment configuration
            $processingOptions = @{
                ServiceName = $ServiceName
                Environment = $EnvironmentType
                AuditLevel = $config.AuditLevel
                RetryCount = $config.RetryCount
                CorrelationId = $CorrelationId
            }

            Write-EnterpriseLog -Level "INFO" -Message "Processing service with options" -Details $processingOptions -CorrelationId $CorrelationId

            # Simulate service processing with configuration-driven behavior
            $serviceData = Invoke-ServiceProcessing @processingOptions

            # Apply environment-specific transformations
            $transformedData = switch ($config.Environment) {
                'Production' {
                    # Production: Full validation and security checks
                    $serviceData | Add-SecurityValidation | Add-ComplianceMetadata
                }
                'Testing' {
                    # Testing: Add debug information and validation
                    $serviceData | Add-TestingMetadata | Add-ValidationResults
                }
                'Development' {
                    # Development: Add extensive debugging information
                    $serviceData | Add-DebugInformation | Add-DeveloperMetadata
                }
            }

            # Create result object with configuration-driven properties
            $result = [PSCustomObject]@{
                PSTypeName = 'ServiceProcessingResult'
                Status = "Success"
                ServiceName = $ServiceName
                Environment = $EnvironmentType
                Data = $transformedData
                ProcessingTime = if ($IncludeMetrics) { $stopwatch.Elapsed } else { $null }
                CorrelationId = $CorrelationId
                Timestamp = Get-Date
                ConfigurationApplied = @{
                    AuditLevel = $config.AuditLevel
                    RetryCount = $config.RetryCount
                    Timeout = $config.ConnectionTimeout
                }
            }

            # Performance validation based on environment
            if ($IncludeMetrics -and $stopwatch.ElapsedMilliseconds -gt $config.PerformanceThreshold) {
                Write-EnterpriseLog -Level "WARN" -Message "Processing exceeded performance threshold" -Details @{
                    ElapsedMs = $stopwatch.ElapsedMilliseconds
                    ThresholdMs = $config.PerformanceThreshold
                    ServiceName = $ServiceName
                } -CorrelationId $CorrelationId
            }

            Write-Output $result
        }
        catch {
            # Modern error handling using $_ instead of $Error[0]
            $errorDetails = @{
                ServiceName = $ServiceName
                Environment = $EnvironmentType
                ErrorMessage = $_.Exception.Message
                ErrorCategory = $_.CategoryInfo.Category.ToString()
                ScriptLineNumber = $_.InvocationInfo.ScriptLineNumber
                CorrelationId = $CorrelationId
            }

            Write-EnterpriseLog -Level "ERROR" -Message "Template function processing failed" -Details $errorDetails -CorrelationId $CorrelationId

            # Environment-appropriate error handling
            if ($config.Environment -eq "Production") {
                # Production: Re-throw to preserve stack trace
                throw $_
            } else {
                # Development/Testing: Return error details for debugging
                $errorResult = [PSCustomObject]@{
                    PSTypeName = 'ServiceProcessingResult'
                    Status = "Error"
                    ServiceName = $ServiceName
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
        if ($IncludeMetrics) {
            $stopwatch.Stop()
            Write-EnterpriseLog -Level "INFO" -Message "Template function processing completed" -Details @{
                TotalElapsedMs = $stopwatch.ElapsedMilliseconds
                ServiceName = $ServiceName
                Environment = $EnvironmentType
            } -CorrelationId $CorrelationId
        } else {
            Write-EnterpriseLog -Level "INFO" -Message "Template function processing completed" -CorrelationId $CorrelationId
        }
    }
}

# Supporting functions (would typically be in separate files)

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

    # Simulate service connection test
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

    # Simulate service processing
    return @{
        ServiceId = [System.Guid]::NewGuid().ToString()
        ProcessedAt = Get-Date
        Status = "Processed"
        Records = 150
    }
}