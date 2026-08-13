# Integration Test Template

Targets **Pester 6.1+**. Uses the `Should-*` assertion syntax - see
[Assertion Guide](./assertion-guide.md).

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Standard Integration Test Structure

Use this template for integration tests that validate component interactions:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }

# Integration tests touch shared external resources - databases, ports, live endpoints -
# so they must not run concurrently with other files.
#pester:no-parallel

BeforeAll {
    # Import module under test. Each file is self-contained in Pester 6.
    $ModulePath = Join-Path $PSScriptRoot '..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force

    # Set up test environment
    $TestEnvironment = @{
        DatabaseConnection = $env:TEST_DATABASE_CONNECTION
        APIEndpoint = $env:TEST_API_ENDPOINT
        TempDirectory = Join-Path $env:TEMP "IntegrationTests"
        TestDataPath = Join-Path $PSScriptRoot "..\TestData"
    }

    # Create test resources
    if (-not (Test-Path $TestEnvironment.TempDirectory)) {
        New-Item -Path $TestEnvironment.TempDirectory -ItemType Directory -Force
    }

    # Load test configuration
    $TestConfig = Import-PowerShellDataFile (Join-Path $TestEnvironment.TestDataPath "integration-config.psd1")
}

AfterAll {
    # Cleanup test resources
    if (Test-Path $TestEnvironment.TempDirectory) {
        Remove-Item -Path $TestEnvironment.TempDirectory -Recurse -Force
    }

    # Cleanup test data
    if ($TestConfig.CleanupRequired) {
        Invoke-TestCleanup -Configuration $TestConfig
    }
}

Describe "Integration Tests" -Tag "Integration", "EndToEnd" {
    Context "End-to-End Workflow" {
        It "Should complete full business process" {
            # Execute complete workflow
            $result = Invoke-CompleteWorkflow -Configuration $TestEnvironment

            # Validate end-to-end results
            $result.Success        | Should-BeTrue
            $result.ProcessedItems | Should-BeGreaterThan 0
            $result.Errors         | Should-BeCollection @()
            $result.ExecutionTime  | Should-BeLessThan ([TimeSpan]::FromMinutes(5))
        }

        It "Should handle partial failures gracefully" {
            # Inject controlled failures
            $testData = Get-TestData -Type 'PartialFailure'

            $result = Invoke-CompleteWorkflow -Configuration $TestEnvironment -TestData $testData

            # Should complete with warnings
            $result.Success        | Should-BeTrue
            $result.Warnings       | Should-NotBeNull
            $result.ProcessedItems | Should-BeGreaterThan 0
        }

        It "Should maintain data consistency across components" {
            $testId = [System.Guid]::NewGuid().ToString()

            # Create data in first component
            New-TestEntity -Id $testId -Data @{ Name = 'IntegrationTest'; Value = 'TestValue' } |
                Should-BeEquivalent ([PSCustomObject]@{ Success = $true }) -ExcludePathsNotOnExpected

            # Retrieve from second component
            Get-TestEntity -Id $testId | Should-BeEquivalent ([PSCustomObject]@{
                Name  = 'IntegrationTest'
                Value = 'TestValue'
            }) -ExcludePathsNotOnExpected

            # Update through third component
            (Set-TestEntity -Id $testId -Value 'UpdatedValue').Success | Should-BeTrue

            # Verify consistency
            (Get-TestEntity -Id $testId).Value | Should-Be 'UpdatedValue'
        }
    }

    Context "External Service Dependencies" {
        BeforeEach {
            # Verify test environment connectivity
            $connectivityTest = Test-ExternalServiceConnectivity -Endpoint $TestEnvironment.APIEndpoint
            if (-not $connectivityTest.Success) {
                Set-ItResult -Skipped -Because "External service not available: $($connectivityTest.Error)"
            }
        }

        It "Should handle external service integration" {
            # Test with real external services (controlled test environment)
            $serviceResult = Test-ExternalServiceIntegration -Endpoint $TestEnvironment.APIEndpoint

            $serviceResult.Connected     | Should-BeTrue
            $serviceResult.ResponseTime  | Should-BeLessThan 5000
            $serviceResult.DataExchanged | Should-BeTrue
        }

        It "Should retry on transient failures" {
            # Simulate transient failure scenario
            $retryResult = Invoke-ServiceWithRetry -Endpoint $TestEnvironment.APIEndpoint -MaxRetries 3

            $retryResult.Success      | Should-BeTrue
            $retryResult.AttemptCount | Should-BeGreaterThan 1
            $retryResult.AttemptCount | Should-BeLessThanOrEqual 3 -Because 'MaxRetries caps attempts at 3'
        }

        It "Should circuit break on persistent failures" {
            # Test circuit breaker pattern
            $circuitResult = Invoke-ServiceWithCircuitBreaker -Endpoint 'http://invalid-endpoint.test'

            $circuitResult.CircuitOpen   | Should-BeTrue
            $circuitResult.ExecutionTime | Should-BeLessThan ([TimeSpan]::FromSeconds(10))
        }
    }

    Context "Data Persistence" {
        It "Should persist data correctly across sessions" {
            $testData = @{
                Name = 'IntegrationTest'
                Value = 'TestValue'
                Timestamp = Get-Date
                ComplexData = @{
                    NestedProperty = 'NestedValue'
                    ArrayProperty = @(1, 2, 3)
                }
            }

            # Save data
            $saveResult = Save-TestData -Data $testData -Connection $TestEnvironment.DatabaseConnection
            $saveResult.Success  | Should-BeTrue
            $saveResult.RecordId | Should-NotBeNull

            # Retrieve data in new session
            $retrievedData = Get-TestData -Id $saveResult.RecordId -Connection $TestEnvironment.DatabaseConnection

            # Verify data integrity. One deep comparison beats four property assertions and
            # reports a property-by-property diff when the round trip loses something.
            # Timestamp is excluded because storage may re-quantize it.
            $retrievedData | Should-BeEquivalent $testData -ExcludePath 'Timestamp'
        }

        It "Should handle concurrent data access" {
            $testId = [System.Guid]::NewGuid().ToString()

            # Create concurrent operations
            $jobs = 1..5 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($TestId, $WorkerId)

                    # Simulate concurrent data access
                    Set-TestData -Id $TestId -Worker $WorkerId -Value "Worker$WorkerId-$(Get-Date -Format 'HHmmss')"
                } -ArgumentList $testId, $_
            }

            # Wait for completion
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job

            # Verify no data corruption
            Get-TestData -Id $testId | Should-NotBeNull
            $results | Should-BeCollection -Count 5
        }

        It "Should maintain referential integrity" {
            # Create parent record
            $parentId = [System.Guid]::NewGuid().ToString()
            (New-TestParent -Id $parentId -Name 'TestParent').Success | Should-BeTrue

            # Create child records
            1..3 | ForEach-Object {
                (New-TestChild -ParentId $parentId -Name "TestChild$_").Success | Should-BeTrue
            }

            # Verify relationships
            $children = Get-TestChildren -ParentId $parentId
            $children | Should-BeCollection -Count 3
            $children | Should-All { $_.ParentId -eq $parentId }

            # Test cascade operations
            (Remove-TestParent -Id $parentId -Cascade).Success | Should-BeTrue

            # Verify cascade worked
            Get-TestChildren -ParentId $parentId | Should-BeCollection @()
        }
    }

    Context "Cross-Platform Compatibility" {
        # Pester 6 supports Windows PowerShell 5.1 and PowerShell 7.4+ only.
        It "Should work on Windows PowerShell 5.1" -Skip:($PSVersionTable.PSVersion.Major -ne 5) {
            $result = Invoke-CrossPlatformFunction -Platform 'Windows' -PowerShellVersion '5.1'
            $result.Success  | Should-BeTrue
            $result.Platform | Should-Be 'Windows'
        }

        It "Should work on PowerShell 7.4+" -Skip:($PSVersionTable.PSVersion -lt [version]'7.4') {
            $result = Invoke-CrossPlatformFunction -Platform $PSVersionTable.Platform -PowerShellVersion $PSVersionTable.PSVersion
            $result.Success               | Should-BeTrue
            $result.CrossPlatformFeatures | Should-BeTrue
        }

        It "Should handle path separators correctly" {
            $testPath = Join-Path 'parent' 'child' 'file.txt'
            $result = Test-PathHandling -Path $testPath

            $result.Success        | Should-BeTrue
            $result.NormalizedPath | Should-NotBeNull

            # Verify platform-specific path handling.
            # $IsWindows is undefined on Windows PowerShell 5.1, which is always Windows.
            $onWindows = $PSVersionTable.PSVersion.Major -eq 5 -or $IsWindows
            if ($onWindows) {
                $result.NormalizedPath | Should-MatchString '\\'
            } else {
                $result.NormalizedPath | Should-MatchString '/'
            }
        }
    }
}
```

## Pester 6 Notes for Integration Tests

### Opt out of parallel execution

Integration tests hold shared external resources - a database, a fixed port, a live endpoint. Two
files touching the same resource concurrently will produce flaky, hard-to-diagnose failures. Put
`#pester:no-parallel` at the top of every integration test file. Those files run serially in the
parent session while unit test files run in parallel.

### `Set-ItResult -Pending` is gone

Use `-Skipped` (with `-Because`) or `-Inconclusive`:

```powershell
BeforeEach {
    $connectivity = Test-ExternalServiceConnectivity -Endpoint $TestEnvironment.APIEndpoint
    if (-not $connectivity.Success) {
        Set-ItResult -Skipped -Because "External service not available: $($connectivity.Error)"
    }
}
```

### Environment-driven test cases must not be empty

An integration suite that builds `-ForEach` from environment configuration will **fail discovery**
in Pester 6 if that configuration is missing, rather than silently running zero tests. This is
usually what you want. Where an empty set is legitimate, be explicit:

```powershell
It "Should reach <Endpoint>" -ForEach $configuredEndpoints -AllowNullOrEmptyForEach {
    Test-Endpoint -Uri $Endpoint | Should-BeTrue
}
```

### Prefer `Should-BeEquivalent` for round trips

Persistence and API tests compare whole objects. One `Should-BeEquivalent` with `-ExcludePath` for
volatile fields (generated ids, timestamps) gives a property-by-property diff, where a run of
individual property assertions only tells you about the first mismatch.

## Integration Test Guidelines

### Test Environment Setup

- Use environment variables for configuration
- Create isolated test resources
- Verify external service availability
- Clean up resources after tests

### End-to-End Testing

- Test complete business workflows
- Validate component interactions
- Verify data flow and consistency
- Test error propagation and recovery

### External Dependencies

- Use real services in controlled environment
- Test connectivity and error handling
- Validate retry and circuit breaker patterns
- Mock only when real services unavailable

### Data Persistence Testing

- Test CRUD operations
- Verify data integrity and consistency
- Test concurrent access scenarios
- Validate referential integrity

### Cross-Platform Considerations

- Test on multiple PowerShell versions
- Verify path handling differences
- Test platform-specific features
- Use conditional test execution
