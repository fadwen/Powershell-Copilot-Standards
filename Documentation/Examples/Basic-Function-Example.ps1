<#
.SYNOPSIS
    Example of a basic enterprise-standard PowerShell function

.DESCRIPTION
    This function demonstrates all the key patterns and standards
    required for enterprise PowerShell development using our
    GitHub Copilot standards.

.PARAMETER ComputerName
    [String[]] (Mandatory: Yes, Pipeline: ByValue, ByPropertyName)
    
    One or more computer names to query for information.
    
    VALIDATION:
    - Must be valid computer names (NetBIOS or FQDN)
    - Pattern: Letters, numbers, hyphens, and dots only
    - Length: 1-255 characters
    
    EXAMPLES:
    - "SERVER01"
    - "web01.contoso.com"
    - @("APP01", "APP02", "DB01")

.PARAMETER Credential
    [PSCredential] (Mandatory: No, Pipeline: No)
    
    Credential to use for remote connections. If not provided,
    uses current user context.

.PARAMETER IncludeServices
    [Switch] (Mandatory: No, Pipeline: No)
    
    Include running services information in the output.

.EXAMPLE
    PS> Get-BasicServerInfo -ComputerName "SERVER01"
    
    DESCRIPTION: Basic server information retrieval
    OUTPUT: Server information object with OS and hardware details
    USE CASE: Daily server health checks

.EXAMPLE
    PS> @("WEB01", "WEB02") | Get-BasicServerInfo -IncludeServices
    
    DESCRIPTION: Pipeline processing with service information
    OUTPUT: Server info objects including running services
    USE CASE: Comprehensive server inventory

.EXAMPLE
    PS> Get-BasicServerInfo -ComputerName "PROD-DB01" -Credential $cred | Export-Csv "server-info.csv"
    
    DESCRIPTION: Secure connection with credential and export
    OUTPUT: CSV file with server information
    USE CASE: Automated reporting for compliance

.NOTES
    Author: Jeffrey Stuhr
    Blog: https://www.techbyjeff.net
    LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/
    Version: 1.0.0
    Last Updated: 2024-01-15
    
    DEPENDENCIES:
    - Windows PowerShell 5.1+ or PowerShell 7.x
    - WinRM enabled on target computers
    - Appropriate permissions on target systems
    
    PERFORMANCE:
    - Execution time: ~10-30 seconds per server
    - Memory usage: ~5MB per server
    - Network bandwidth: Minimal (WMI queries only)
    
    TROUBLESHOOTING:
    - Connection issues: .\Troubleshooting\Common\Function-Issues.md
    - WinRM problems: .\Troubleshooting\Security\WinRM-Setup.md
    - Performance: .\Troubleshooting\Performance\Server-Monitoring.md
#>

function Get-BasicServerInfo {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, 
                   ValueFromPipeline = $true,
                   ValueFromPipelineByPropertyName = $true,
                   HelpMessage = "Enter one or more computer names")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9\-\.]+$')]
        [ValidateLength(1, 255)]
        [Alias('CN', 'ServerName', 'Name')]
        [string[]]$ComputerName,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        
        [Parameter()]
        [switch]$IncludeServices
    )
    
    begin {
        # Initialize correlation tracking for enterprise monitoring
        $correlationId = [System.Guid]::NewGuid()
        $startTime = Get-Date
        
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name) - CorrelationId: $correlationId"
        Write-Verbose "Parameters: ComputerName count = $($ComputerName.Count), IncludeServices = $IncludeServices"
        
        # Initialize counters for performance tracking
        $processedCount = 0
        $successCount = 0
        $failureCount = 0
        
        # Prepare credential for CIM sessions if provided
        $cimSessionOptions = New-CimSessionOption -Protocol WSMan
        $sessionParams = @{
            SessionOption = $cimSessionOptions
            ErrorAction = 'Stop'
        }
        if ($Credential) {
            $sessionParams.Credential = $Credential
        }
    }
    
    process {
        foreach ($computer in $ComputerName) {
            $processedCount++
            $computerStartTime = Get-Date
            
            try {
                Write-Verbose "Processing computer: $computer (CorrelationId: $correlationId)"
                
                if ($PSCmdlet.ShouldProcess($computer, "Retrieve server information")) {
                    
                    # Test connectivity first
                    $connectionTest = Test-Connection -ComputerName $computer -Count 1 -Quiet -ErrorAction SilentlyContinue
                    if (-not $connectionTest) {
                        throw "Computer $computer is not reachable via ping"
                    }
                    
                    # Create CIM session for efficient querying
                    $sessionParams.ComputerName = $computer
                    $cimSession = New-CimSession @sessionParams
                    
                    try {
                        # Gather basic system information
                        Write-Verbose "Querying system information for $computer"
                        $os = Get-CimInstance -CimSession $cimSession -ClassName Win32_OperatingSystem
                        $computerSystem = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem
                        $processor = Get-CimInstance -CimSession $cimSession -ClassName Win32_Processor | Select-Object -First 1
                        
                        # Calculate uptime
                        $uptime = (Get-Date) - $os.LastBootUpTime
                        
                        # Build result object with raw data for maximum reusability
                        $result = [PSCustomObject]@{
                            ComputerName = $computer
                            OperatingSystem = $os.Caption
                            Version = $os.Version
                            ServicePackLevel = $os.ServicePackMajorVersion
                            Architecture = $os.OSArchitecture
                            LastBootTime = $os.LastBootUpTime
                            UptimeDays = [math]::Round($uptime.TotalDays, 2)
                            TotalMemoryGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
                            Manufacturer = $computerSystem.Manufacturer
                            Model = $computerSystem.Model
                            ProcessorName = $processor.Name
                            ProcessorCores = $processor.NumberOfCores
                            ProcessorLogicalProcessors = $processor.NumberOfLogicalProcessors
                            Domain = $computerSystem.Domain
                            Workgroup = $computerSystem.Workgroup
                            CorrelationId = $correlationId
                            QueryTime = Get-Date
                            QueryDurationMs = ((Get-Date) - $computerStartTime).TotalMilliseconds
                        }
                        
                        # Add services information if requested
                        if ($IncludeServices) {
                            Write-Verbose "Querying services information for $computer"
                            $runningServices = Get-CimInstance -CimSession $cimSession -ClassName Win32_Service |
                                Where-Object State -eq 'Running' |
                                Select-Object Name, DisplayName, StartMode
                            
                            $result | Add-Member -MemberType NoteProperty -Name 'RunningServices' -Value $runningServices
                            $result | Add-Member -MemberType NoteProperty -Name 'RunningServiceCount' -Value $runningServices.Count
                        }
                        
                        $successCount++
                        Write-Verbose "Successfully processed $computer in $([math]::Round($result.QueryDurationMs, 0))ms"
                        
                        # Return the result object
                        $result
                        
                    }
                    finally {
                        # Clean up CIM session
                        if ($cimSession) {
                            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
                        }
                    }
                }
                
            }
            catch {
                $failureCount++
                $errorDetails = @{
                    ComputerName = $computer
                    CorrelationId = $correlationId
                    ErrorMessage = $_.Exception.Message
                    ErrorTime = Get-Date
                    Function = $MyInvocation.MyCommand.Name
                }
                
                Write-Error "Failed to process computer '$computer': $($_.Exception.Message) (CorrelationId: $correlationId)"
                Write-Verbose "Error details: $($errorDetails | ConvertTo-Json -Compress)"
                
                # Continue processing other computers instead of terminating
                continue
            }
        }
    }
    
    end {
        $endTime = Get-Date
        $totalDuration = ($endTime - $startTime).TotalSeconds
        
        # Performance and summary logging
        $summary = @{
            CorrelationId = $correlationId
            TotalComputers = $processedCount
            SuccessfulQueries = $successCount
            FailedQueries = $failureCount
            SuccessRate = if ($processedCount -gt 0) { [math]::Round(($successCount / $processedCount) * 100, 1) } else { 0 }
            TotalDurationSeconds = [math]::Round($totalDuration, 2)
            AverageTimePerServer = if ($successCount -gt 0) { [math]::Round($totalDuration / $successCount, 2) } else { 0 }
        }
        
        Write-Verbose "Completed $($MyInvocation.MyCommand.Name) - Summary: $($summary | ConvertTo-Json -Compress)"
        
        if ($failureCount -gt 0) {
            Write-Warning "Operation completed with $failureCount failures out of $processedCount computers. Check error messages above for details."
        }
    }
}
