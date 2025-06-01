function Test-QualityGates {
    <#
    .SYNOPSIS
        Test function to demonstrate quality gate enforcement

    .DESCRIPTION
        This function intentionally contains several quality issues that should be
        caught by the PowerShell quality gates, including parameter validation issues,
        performance anti-patterns, and security concerns.

    .PARAMETER UserName
        The username to process

    .PARAMETER ServerList
        List of servers to check

    .PARAMETER ProcessData
        Data to process in loops

    .PARAMETER Credential
        Credential object for secure authentication

    .PARAMETER CorrelationId
        Correlation ID for audit trail

    .EXAMPLE
        Test-QualityGates -UserName "testuser" -ServerList @("server1", "server2") -Credential (Get-Credential)

        Demonstrates basic usage with quality issues present.

    .NOTES
        Author: Jeffrey Stuhr
        Purpose: Quality gate testing and demonstration
    #>
    [CmdletBinding()]
    [OutputType('QualityGateTestResult')]
    param(
        [Parameter(Mandatory)]
        [string]$UserName,

        [Parameter()]
        [string[]]$ServerList,

        [Parameter()]
        [object[]]$ProcessData,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-Verbose "Starting quality gate test... CorrelationId: $CorrelationId"

        # Use ArrayList for performance in loops
        $results = [System.Collections.ArrayList]::new()
    }

    process {
        try {
            Write-Verbose "Processing user: $UserName - CorrelationId: $CorrelationId"

            # Parameter validation before downstream usage
            if (-not $UserName.Trim()) {
                Write-Error "UserName cannot be empty or whitespace" -ErrorAction Stop
                return
            }

            # Secure credential usage (example: pass to downstream cmdlet)
            # $userInfo = Get-ADUser -Identity $UserName -Credential $Credential -ErrorAction Stop
            $userInfo = Get-ADUser -Identity $UserName -ErrorAction Stop

            # Performance: use ArrayList for results
            if ($ServerList) {
                foreach ($server in $ServerList) {
                    [void]$results.Add("Processing $server")
                }
            }

            # Use StringBuilder for large string concatenation
            $sb = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt 1000; $i++) {
                [void]$sb.AppendLine("Log entry $i")
            }
            $logOutput = $sb.ToString()

            # SQL injection mitigation: use parameterized queries (example shown as comment)
            # $query = "SELECT * FROM Users WHERE Name = @UserName"
            # $command.Parameters.Add((New-Object Data.SqlClient.SqlParameter("@UserName", $UserName)))
            $query = "SELECT * FROM Users WHERE Name = @UserName"  # Example only

            # Proper error termination
            if (-not $userInfo) {
                Write-Error "User not found: $UserName" -ErrorAction Stop
                return
            }

            # Create result with descriptive type
            $result = [PSCustomObject]@{
                PSTypeName = 'QualityGateTestResult'
                UserName = $UserName
                ServersProcessed = $results.Count
                LogSize = $logOutput.Length
                DatabaseQuery = $query
                ProcessedAt = Get-Date
                CorrelationId = $CorrelationId
            }

            Write-Output $result
        }
        catch {
            # Use $_ in catch blocks
            $errorDetails = @{
                UserName = $UserName
                ErrorMessage = $_.Exception.Message
                CorrelationId = $CorrelationId
            }
            Write-Error "Processing failed: $($_.Exception.Message) - CorrelationId: $CorrelationId" -ErrorAction Stop
        }
    }

    end {
        Write-Verbose "Quality gate test completed - CorrelationId: $CorrelationId"
    }
}

# Additional function with approved verb and proper standards
function Test-TestData {
    <#
    .SYNOPSIS
        Test data processing using approved verb

    .PARAMETER Data
        Data to process

    .EXAMPLE
        Test-TestData -Data "Sample"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Data
    )

    Write-Output "Processed: $Data"
}

# Function with correct patterns for comparison
function Get-TestResults {
    <#
    .SYNOPSIS
        Correctly implemented function following all standards

    .DESCRIPTION
        This function demonstrates proper PowerShell patterns that should pass
        all quality gates without issues.

    .PARAMETER TestName
        Name of the test to run

    .PARAMETER CorrelationId
        Correlation ID for audit trail

    .EXAMPLE
        Get-TestResults -TestName "SecurityTest"

        Runs the specified test and returns results.

    .OUTPUTS
        TestResult. Returns test execution results.
    #>
    [CmdletBinding()]
    [OutputType([TestResult])]
    param(
        [Parameter(Mandatory)]
        [string]$TestName,

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-Verbose "Starting test: $TestName - CorrelationId: $CorrelationId"
    }

    process {
        try {
            if (-not $TestName.Trim()) {
                Write-Error "TestName cannot be empty or whitespace" -ErrorAction Stop
                return
            }

            $testResult = [PSCustomObject]@{
                PSTypeName = 'TestResult'
                TestName = $TestName.Trim()
                Status = 'Passed'
                CorrelationId = $CorrelationId
                ExecutedAt = Get-Date
            }

            Write-Output $testResult
        }
        catch {
            $errorDetails = @{
                TestName = $TestName
                ErrorMessage = $_.Exception.Message
                CorrelationId = $CorrelationId
            }

            Write-Verbose "Test failed: $TestName - Error: $($_.Exception.Message)"
            Write-Error "Test execution failed: $($_.Exception.Message)" -ErrorAction Stop
        }
    }

    end {
        Write-Verbose "Test completed: $TestName - CorrelationId: $CorrelationId"
    }
}