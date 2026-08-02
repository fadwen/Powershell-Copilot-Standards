# =============================================================================
# DO NOT COPY FROM THIS FILE WITHOUT READING THIS HEADER.
#
# Test-QualityGates and Process-TestData DELIBERATELY VIOLATE THE STANDARDS.
# They exist so the quality gates have something to catch. Running
# Tools/Test-StandardsCompliance.ps1 against this file reports UseApprovedVerbs,
# AvoidPSCustomObjectOutputType and UseDollarUnderscoreInCatch, which is the
# point. Both CI workflows exclude it from production analysis by name.
#
# Violations present on purpose, all of them in those two functions: Write-Host
# instead of Write-Verbose, $Error[0] in catch blocks instead of $_, a
# non-approved verb (Process-TestData), array appending in a loop, string
# concatenation in a loop, a redundant ValidateNotNullOrEmpty on a mandatory
# parameter, an unused parameter, and [OutputType([PSCustomObject])].
#
# Get-TestResult, at the bottom, is the one compliant function in the file and
# is here as the contrast. It passes PSScriptAnalyzer clean. For fuller models
# see Basic-Function-Example.ps1 or Module-Structure-Example/.
#
# Security issues are NOT among the deliberate violations - plaintext
# credentials and interpolated SQL were removed, so this file is safe to keep in
# the repository. The spots where that matters are marked "Not a violation".
# =============================================================================

function Test-QualityGates {
    <#
    .SYNOPSIS
    Deliberately non-compliant function used to prove the quality gates fire.

    .DESCRIPTION
    Contains quality violations on purpose - see the file header for the list.
    Not a model. Security issues specifically are absent, so the file is safe to
    keep in the repository.

    .PARAMETER UserName
    The username to process

    .PARAMETER ServerList
    List of servers to check

    .PARAMETER ProcessData
    Data to process in loops

    .PARAMETER DatabaseCredential
    Secure credential for database access

    .PARAMETER UnusedParameter
    Declared and never referenced - one of the deliberate violations

    .EXAMPLE
    $cred = Get-Credential
    Test-QualityGates -UserName "testuser" -ServerList @("server1", "server2") -DatabaseCredential $cred

    Demonstrates the call shape. The quality violations are in the body.

    .NOTES
    Purpose: Quality gate testing and demonstration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]  # Violation: should be a descriptive type name
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]  # Violation: redundant on a mandatory parameter
        [string]$UserName,

        [Parameter()]
        [string[]]$ServerList,

        [Parameter()]
        [object[]]$ProcessData,

        [Parameter()]
        [PSCredential]$DatabaseCredential,  # Not a violation: PSCredential, not plain text

        [Parameter()]
        [string]$UnusedParameter  # Violation: declared and never referenced
    )

    begin {
        Write-Host "Starting quality gate test..." -ForegroundColor Green  # Violation: Write-Host

        # Violation: array built by appending in the loop below
        $results = @()

        # Not a violation: the credential is never expanded to plain text
        if ($DatabaseCredential) {
            Write-Verbose "Database credential provided securely"
        } else {
            Write-Verbose "No database credential provided"
        }
    }

    process {
        try {
            Write-Verbose "Processing user: $UserName"

            # Violation: result used downstream without being checked first
            $userInfo = Get-ADUser -Identity $UserName

            # Violation: array appending in a loop reallocates on every pass
            foreach ($server in $ServerList) {
                $results += "Processing $server"
            }

            # Violation: string concatenation in a loop - StringBuilder belongs here
            $logOutput = ""
            for ($i = 0; $i -lt 1000; $i++) {
                $logOutput += "Log entry $i`n"
            }

            # Not a violation: parameterized query, not string interpolation
            $query = "SELECT * FROM Users WHERE Name = @UserName"
            $queryParams = @{ UserName = $UserName }

            # Violation: a bare throw here can be silenced by -ErrorAction SilentlyContinue
            if (-not $userInfo) {
                throw "User not found: $UserName"
            }

            $result = [PSCustomObject]@{
                UserName = $UserName
                ServersProcessed = $results.Count
                LogSize = $logOutput.Length
                DatabaseQuery = $query
                QueryParameters = $queryParams
                HasDatabaseCredential = [bool]$DatabaseCredential
                ProcessedAt = Get-Date
            }

            return $result
        }
        catch {
            # Violation: $Error[0] instead of $_ - $Error is global and mutable, so
            # this can report an unrelated error
            $currentError = $Error[0]
            Write-Error "Processing failed: $($currentError.Exception.Message)"
            throw
        }
    }

    end {
        Write-Host "Quality gate test completed" -ForegroundColor Yellow  # Violation: Write-Host
    }
}


# Violation: "Process" is not an approved PowerShell verb - see Get-Verb
function Process-TestData {
    param(
        [string]$Data
    )

    return "Processed: $Data"
}


function Get-TestResult {
    <#
    .SYNOPSIS
    The compliant contrast to the two functions above.

    .DESCRIPTION
    Demonstrates the patterns the standards ask for: an approved verb with a
    singular noun, a mandatory parameter without a redundant validator,
    correlation ID tracking, $_ in the catch block, and a PSTypeName-stamped
    output object. Passes PSScriptAnalyzer clean.

    .PARAMETER TestName
    Name of the test to run

    .PARAMETER CorrelationId
    Correlation ID for tracing; generated when not supplied

    .EXAMPLE
    Get-TestResult -TestName "SecurityTest"

    Runs the specified test and returns the result.

    .OUTPUTS
    TestResult. Returns test execution results.
    #>
    [CmdletBinding()]
    # Descriptive type name. Quoted: 'TestResult' is the PSTypeName applied to the
    # output object below, not a .NET type - [OutputType([TestResult])] fails to resolve.
    [OutputType('TestResult')]
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
            # Validate before downstream use. Mandatory rejects '' at binding time,
            # but whitespace binds fine and still has to be caught.
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
            # Correct: $_ in the catch block, and the structured detail is emitted
            # rather than assembled and dropped
            $errorDetails = @{
                TestName = $TestName
                ErrorMessage = $_.Exception.Message
                CorrelationId = $CorrelationId
            }

            Write-Verbose ("Test failed: {0} - Error: {1} - CorrelationId: {2}" -f
                $errorDetails.TestName, $errorDetails.ErrorMessage, $errorDetails.CorrelationId)
            Write-Error "Test execution failed: $($_.Exception.Message)" -ErrorAction Stop
        }
    }

    end {
        Write-Verbose "Test completed: $TestName - CorrelationId: $CorrelationId"
    }
}
