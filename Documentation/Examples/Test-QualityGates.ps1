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

    .EXAMPLE
    Test-QualityGates -UserName "testuser" -ServerList @("server1", "server2")

    Demonstrates basic usage with quality issues present.

    .NOTES
    Author: Jeffrey Stuhr
    Purpose: Quality gate testing and demonstration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]  # This should be descriptive type name
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]  # Expert feedback: redundant on mandatory params
        [string]$UserName,

        [Parameter()]
        [string[]]$ServerList,

        [Parameter()]
        [object[]]$ProcessData,

        [Parameter()]
        [string]$DatabasePassword = "admin123",  # Security issue: hardcoded password

        [Parameter()]
        [string]$UnusedParameter  # Quality issue: unused parameter
    )

    begin {
        Write-Host "Starting quality gate test..." -ForegroundColor Green  # Issue: using Write-Host

        # Performance issue: building arrays in loops
        $results = @()

        # Security issue: credential handling
        $plainPassword = "MySecretPassword123"  # Hardcoded credential
    }

    process {
        try {
            # Issue: using $Error[0] instead of $_ (expert feedback)
            Write-Verbose "Processing user: $UserName"

            # Parameter validation issue: not checking before downstream usage
            $userInfo = Get-ADUser -Identity $UserName  # Could fail if UserName is empty

            # Performance anti-pattern: array appending in loop
            foreach ($server in $ServerList) {
                $results += "Processing $server"  # Creates new array each time
            }

            # String concatenation issue: should use StringBuilder for large operations
            $logOutput = ""
            for ($i = 0; $i -lt 1000; $i++) {
                $logOutput += "Log entry $i`n"  # Inefficient for large operations
            }

            # Security issue: SQL injection risk
            $query = "SELECT * FROM Users WHERE Name = '$UserName'"  # Direct string interpolation

            # Issue: throw that can be silenced (expert feedback Part 2)
            if (-not $userInfo) {
                throw "User not found: $UserName"  # Can be silenced with -ErrorAction SilentlyContinue
            }

            # Create result with quality issues
            $result = [PSCustomObject]@{
                UserName = $UserName
                ServersProcessed = $results.Count
                LogSize = $logOutput.Length
                DatabaseQuery = $query
                ProcessedAt = Get-Date
            }

            return $result
        }
        catch {
            # Issue: using $Error[0] instead of $_ (expert feedback Part 1)
            $currentError = $Error[0]  # Should use $_ in catch blocks
            Write-Error "Processing failed: $($currentError.Exception.Message)"
            throw
        }
    }

    end {
        Write-Host "Quality gate test completed" -ForegroundColor Yellow  # Issue: Write-Host again
    }
}

# Additional function with non-approved verb (quality issue)
function Process-TestData {  # Issue: "Process" is not an approved PowerShell verb
    param(
        [string]$Data
    )

    # Simple processing
    return "Processed: $Data"
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

    .EXAMPLE
    Get-TestResults -TestName "SecurityTest"

    Runs the specified test and returns results.

    .OUTPUTS
    TestResult. Returns test execution results.
    #>
    [CmdletBinding()]
    [OutputType([TestResult])]  # Descriptive type name
    param(
        [Parameter(Mandatory)]  # No redundant ValidateNotNullOrEmpty
        [string]$TestName,

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-Verbose "Starting test: $TestName - CorrelationId: $CorrelationId"
    }

    process {
        try {
            # Proper parameter validation before downstream usage
            if (-not $TestName.Trim()) {
                Write-Error "TestName cannot be empty or whitespace" -ErrorAction Stop
                return
            }

            # Simulate test execution
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
            # Correct error handling using $_ (expert feedback)
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