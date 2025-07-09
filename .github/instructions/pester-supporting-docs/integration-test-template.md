# Integration Test Template

## Standard Integration Test Structure

Use this template for integration tests that validate component interactions:

```powershell
#Requires -Module Pester

BeforeAll {
    # Import module under test
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
            $result.Success | Should -Be $true
            $result.ProcessedItems | Should -BeGreaterThan 0
            $result.Errors | Should -Be @()
            $result.ExecutionTime | Should -BeLessThan ([TimeSpan]::FromMinutes(5))
        }

        It "Should handle partial failures gracefully" {
            # Inject controlled failures
            $testData = Get-TestData -Type 'PartialFailure'

            $result = Invoke-CompleteWorkflow -Configuration $TestEnvironment -TestData $testData

            # Should complete with warnings
            $result.Success | Should -Be $true
            $result.Warnings | Should -Not -BeNullOrEmpty
            $result.ProcessedItems | Should -BeGreaterThan 0
        }

        It "Should maintain data consistency across components" {
            $testId = [System.Guid]::NewGuid().ToString()

            # Create data in first component
            $createResult = New-TestEntity -Id $testId -Data @{ Name = 'IntegrationTest'; Value = 'TestValue' }
            $createResult.Success | Should -Be $true

            # Retrieve from second component
            $retrieveResult = Get-TestEntity -Id $testId
            $retrieveResult.Name | Should -Be 'IntegrationTest'
            $retrieveResult.Value | Should -Be 'TestValue'

            # Update through third component
            $updateResult = Set-TestEntity -Id $testId -Value 'UpdatedValue'
            $updateResult.Success | Should -Be $true

            # Verify consistency
            $finalResult = Get-TestEntity -Id $testId
            $finalResult.Value | Should -Be 'UpdatedValue'
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

            $serviceResult.Connected | Should -Be $true
            $serviceResult.ResponseTime | Should -BeLessThan 5000
            $serviceResult.DataExchanged | Should -Be $true
        }

        It "Should retry on transient failures" {
            # Simulate transient failure scenario
            $retryResult = Invoke-ServiceWithRetry -Endpoint $TestEnvironment.APIEndpoint -MaxRetries 3

            $retryResult.Success | Should -Be $true
            $retryResult.AttemptCount | Should -BeGreaterThan 1
            $retryResult.AttemptCount | Should -BeLessOrEqual 3
        }

        It "Should circuit break on persistent failures" {
            # Test circuit breaker pattern
            $circuitResult = Invoke-ServiceWithCircuitBreaker -Endpoint 'http://invalid-endpoint.test'

            $circuitResult.CircuitOpen | Should -Be $true
            $circuitResult.ExecutionTime | Should -BeLessThan ([TimeSpan]::FromSeconds(10))
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
            $saveResult.Success | Should -Be $true
            $saveResult.RecordId | Should -Not -BeNullOrEmpty

            # Retrieve data in new session
            $retrievedData = Get-TestData -Id $saveResult.RecordId -Connection $TestEnvironment.DatabaseConnection

            # Verify data integrity
            $retrievedData.Name | Should -Be $testData.Name
            $retrievedData.Value | Should -Be $testData.Value
            $retrievedData.ComplexData.NestedProperty | Should -Be $testData.ComplexData.NestedProperty
            $retrievedData.ComplexData.ArrayProperty.Count | Should -Be 3
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
            $finalData = Get-TestData -Id $testId
            $finalData | Should -Not -BeNullOrEmpty
            $results | Should -HaveCount 5
        }

        It "Should maintain referential integrity" {
            # Create parent record
            $parentId = [System.Guid]::NewGuid().ToString()
            $parentResult = New-TestParent -Id $parentId -Name 'TestParent'
            $parentResult.Success | Should -Be $true

            # Create child records
            $childIds = 1..3 | ForEach-Object {
                $childResult = New-TestChild -ParentId $parentId -Name "TestChild$_"
                $childResult.Success | Should -Be $true
                $childResult.Id
            }

            # Verify relationships
            $children = Get-TestChildren -ParentId $parentId
            $children.Count | Should -Be 3
            $children | ForEach-Object { $_.ParentId | Should -Be $parentId }

            # Test cascade operations
            $deleteResult = Remove-TestParent -Id $parentId -Cascade
            $deleteResult.Success | Should -Be $true

            # Verify cascade worked
            $orphanChildren = Get-TestChildren -ParentId $parentId
            $orphanChildren | Should -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should work on Windows PowerShell 5.1" -Skip:(-not $IsWindows -or $PSVersionTable.PSVersion.Major -ne 5) {
            $result = Invoke-CrossPlatformFunction -Platform 'Windows' -PowerShellVersion '5.1'
            $result.Success | Should -Be $true
            $result.Platform | Should -Be 'Windows'
        }

        It "Should work on PowerShell 7.x" -Skip:($PSVersionTable.PSVersion.Major -lt 7) {
            $result = Invoke-CrossPlatformFunction -Platform $PSVersionTable.Platform -PowerShellVersion $PSVersionTable.PSVersion
            $result.Success | Should -Be $true
            $result.CrossPlatformFeatures | Should -Be $true
        }

        It "Should handle path separators correctly" {
            $testPath = Join-Path 'parent' 'child' 'file.txt'
            $result = Test-PathHandling -Path $testPath

            $result.Success | Should -Be $true
            $result.NormalizedPath | Should -Not -BeNullOrEmpty

            # Verify platform-specific path handling
            if ($IsWindows) {
                $result.NormalizedPath | Should -Match '\\'
            } else {
                $result.NormalizedPath | Should -Match '/'
            }
        }
    }
}
```

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
