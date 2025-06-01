---
mode: 'agent'
applyTo: "**/Tests/**/*.ps1,**/*.Tests.ps1,**/Test-*.ps1"
tools: ['codebase', 'githubRepo']
description: 'Creates comprehensive Pester test suites for PowerShell code with enterprise testing standards'
---

# PowerShell Testing with Pester Framework

Create comprehensive, enterprise-grade test suites using Pester framework that ensure PowerShell code quality, reliability, and maintainability across all environments. Generate tests that support automated CI/CD pipelines and provide comprehensive coverage.

## Test Suite Planning

### Test Strategy Assessment
Determine testing requirements and approach:

#### Testing Scope
- **Functions to Test**: Public functions (mandatory), private functions (recommended)
- **Test Types**: Unit, Integration, Performance, Security tests
- **Coverage Target**: Minimum 80% code coverage for production code
- **Test Environment**: Development, CI/CD pipeline, cross-platform requirements
- **External Dependencies**: APIs, databases, file systems, network resources

#### Quality Requirements
- **Execution Speed**: Unit tests under 30 seconds total, integration tests under 5 minutes
- **Reliability**: Tests must be deterministic and repeatable
- **Isolation**: Tests must be independent and run in any order
- **Maintainability**: Clear test structure and documentation

## Test Structure Generation

### Complete Test Suite Structure
Create organized test directory structure:

```
Tests/
├── Unit/
│   ├── Public/
│   │   ├── Get-ServerHealth.Tests.ps1
│   │   └── Set-Configuration.Tests.ps1
│   ├── Private/
│   │   ├── Test-Connection.Tests.ps1
│   │   └── Format-Output.Tests.ps1
│   └── Classes/
│       └── ServerManager.Tests.ps1
├── Integration/
│   ├── EndToEnd/
│   └── SystemIntegration/
├── Performance/
│   ├── Benchmarks/
│   └── LoadTests/
├── Security/
│   ├── InputValidation/
│   └── CredentialHandling/
├── TestData/
│   ├── sample-data.json
│   └── test-config.psd1
├── TestHelpers/
│   └── TestHelpers.ps1
└── Invoke-Tests.ps1
```

### Unit Test Template
Generate comprehensive unit tests following enterprise patterns:

```powershell
#Requires -Module Pester

BeforeAll {
    # Import module under test
    $ModulePath = Join-Path $PSScriptRoot '..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force

    # Import test helpers
    . $PSScriptRoot\..\TestHelpers\TestHelpers.ps1

    # Mock external dependencies at module level
    Mock Write-Verbose { } -ModuleName ModuleName
    Mock Write-Information { } -ModuleName ModuleName
}

Describe "Function-Name" -Tag "Unit", "Public" {
    Context "Parameter Validation" {
        It "Should accept valid input: <TestCase>" -TestCases @(
            @{ Input = 'ValidValue1'; Expected = 'ExpectedResult1' }
            @{ Input = 'ValidValue2'; Expected = 'ExpectedResult2' }
            @{ Input = 'ValidValue3'; Expected = 'ExpectedResult3' }
        ) {
            param($Input, $Expected)

            $result = Function-Name -ParameterName $Input
            $result | Should -Be $Expected
        }

        It "Should reject invalid input: <InvalidInput>" -TestCases @(
            @{ InvalidInput = $null; ExpectedError = '*cannot be null*' }
            @{ InvalidInput = ''; ExpectedError = '*cannot be empty*' }
            @{ InvalidInput = 'Invalid@#$'; ExpectedError = '*invalid characters*' }
        ) {
            param($InvalidInput, $ExpectedError)

            { Function-Name -ParameterName $InvalidInput } | Should -Throw $ExpectedError
        }

        It "Should support pipeline input" {
            $pipelineInput = @('Value1', 'Value2', 'Value3')
            $results = $pipelineInput | Function-Name
            $results.Count | Should -Be 3
        }
    }

    Context "Core Functionality" {
        BeforeEach {
            # Set up mocks for each test
            Mock External-Dependency {
                return @{ Status = 'Success'; Data = 'MockedData' }
            } -ModuleName ModuleName

            Mock Get-ExternalResource {
                return [PSCustomObject]@{
                    Name = 'TestResource'
                    Value = 'TestValue'
                }
            } -ModuleName ModuleName
        }

        It "Should return expected object structure" {
            $result = Function-Name -ParameterName 'TestValue'

            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSCustomObject]
            $result.PropertyName | Should -Be 'ExpectedValue'
        }

        It "Should call external dependencies with correct parameters" {
            Function-Name -ParameterName 'TestValue'

            Should -Invoke External-Dependency -Exactly 1 -ModuleName ModuleName -ParameterFilter {
                $Parameter -eq 'TestValue'
            }
        }

        It "Should handle multiple items correctly" {
            $testItems = @('Item1', 'Item2', 'Item3')
            $results = Function-Name -ParameterName $testItems

            $results.Count | Should -Be 3
            $results | ForEach-Object { $_.Status | Should -Be 'Processed' }
        }
    }

    Context "Error Handling" {
        It "Should handle external dependency failures gracefully" {
            Mock External-Dependency {
                throw 'External service unavailable'
            } -ModuleName ModuleName

            { Function-Name -ParameterName 'TestValue' } | Should -Throw '*External service unavailable*'
        }

        It "Should provide meaningful error messages" {
            Mock External-Dependency {
                throw 'Connection timeout'
            } -ModuleName ModuleName

            try {
                Function-Name -ParameterName 'TestValue' -ErrorAction Stop
            }
            catch {
                $_.Exception.Message | Should -Match 'Connection timeout'
            }
        }

        It "Should continue processing other items when one fails" {
            Mock External-Dependency {
                if ($Parameter -eq 'FailingItem') {
                    throw 'Item processing failed'
                }
                return @{ Status = 'Success' }
            } -ModuleName ModuleName

            $testItems = @('GoodItem1', 'FailingItem', 'GoodItem2')
            $results = Function-Name -ParameterName $testItems -ErrorAction SilentlyContinue

            # Should process the good items despite one failure
            $successfulResults = $results | Where-Object { $_.Status -eq 'Success' }
            $successfulResults.Count | Should -Be 2
        }
    }

    Context "Performance Requirements" {
        It "Should complete within acceptable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            Function-Name -ParameterName 'TestValue'

            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # 5 seconds max
        }

        It "Should scale linearly with input size" {
            $smallInput = 1..10
            $largeInput = 1..100

            $smallTime = Measure-Command { Function-Name -ParameterName $smallInput }
            $largeTime = Measure-Command { Function-Name -ParameterName $largeInput }

            # Large input should not be more than 15x slower (allows for overhead)
            $scalingRatio = $largeTime.TotalMilliseconds / $smallTime.TotalMilliseconds
            $scalingRatio | Should -BeLessThan 15
        }
    }
}
```

### Integration Test Template
Create integration tests for component interactions:

```powershell
Describe "Integration Tests" -Tag "Integration" {
    BeforeAll {
        # Set up test environment
        $TestEnvironment = @{
            DatabaseConnection = $env:TEST_DATABASE_CONNECTION
            APIEndpoint = $env:TEST_API_ENDPOINT
            TempDirectory = Join-Path $env:TEMP "IntegrationTests"
        }

        # Create test resources
        if (-not (Test-Path $TestEnvironment.TempDirectory)) {
            New-Item -Path $TestEnvironment.TempDirectory -ItemType Directory
        }
    }

    AfterAll {
        # Cleanup test resources
        if (Test-Path $TestEnvironment.TempDirectory) {
            Remove-Item -Path $TestEnvironment.TempDirectory -Recurse -Force
        }
    }

    Context "End-to-End Workflow" {
        It "Should complete full business process" {
            # Execute complete workflow
            $result = Invoke-CompleteWorkflow -Configuration $TestEnvironment

            # Validate end-to-end results
            $result.Success | Should -Be $true
            $result.ProcessedItems | Should -BeGreaterThan 0
            $result.Errors | Should -Be @()
        }

        It "Should handle external service dependencies" {
            # Test with real external services (controlled test environment)
            $serviceResult = Test-ExternalServiceIntegration -Endpoint $TestEnvironment.APIEndpoint

            $serviceResult.Connected | Should -Be $true
            $serviceResult.ResponseTime | Should -BeLessThan 5000
        }
    }

    Context "Data Persistence" {
        It "Should persist data correctly" {
            $testData = @{
                Name = 'IntegrationTest'
                Value = 'TestValue'
                Timestamp = Get-Date
            }

            # Save and retrieve data
            Save-TestData -Data $testData -Connection $TestEnvironment.DatabaseConnection
            $retrievedData = Get-TestData -Name $testData.Name -Connection $TestEnvironment.DatabaseConnection

            $retrievedData.Name | Should -Be $testData.Name
            $retrievedData.Value | Should -Be $testData.Value
        }
    }
}
```

### Performance Test Template
Implement performance benchmarking and regression detection:

```powershell
Describe "Performance Tests" -Tag "Performance" {
    Context "Execution Time Baselines" {
        It "Should process single item within baseline" {
            $baseline = [TimeSpan]::FromSeconds(1)

            $executionTime = Measure-Command {
                Function-Name -ParameterName 'SingleItem'
            }

            $executionTime | Should -BeLessThan $baseline
        }

        It "Should scale efficiently with data volume" {
            $baselineItems = 1..10
            $scaledItems = 1..100

            $baselineTime = Measure-Command {
                Function-Name -ParameterName $baselineItems
            }

            $scaledTime = Measure-Command {
                Function-Name -ParameterName $scaledItems
            }

            # Should scale sub-linearly due to optimizations
            $scalingFactor = $scaledTime.TotalMilliseconds / $baselineTime.TotalMilliseconds
            $scalingFactor | Should -BeLessThan 15  # Allow for some overhead
        }
    }

    Context "Memory Usage" {
        It "Should maintain reasonable memory footprint" {
            $beforeMemory = [System.GC]::GetTotalMemory($true)

            Function-Name -ParameterName (1..1000)

            $afterMemory = [System.GC]::GetTotalMemory($true)
            $memoryUsed = ($afterMemory - $beforeMemory) / 1MB

            $memoryUsed | Should -BeLessThan 50  # Less than 50MB for 1000 items
        }

        It "Should release memory after completion" {
            $beforeMemory = [System.GC]::GetTotalMemory($true)

            Function-Name -ParameterName (1..1000)
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            $afterMemory = [System.GC]::GetTotalMemory($true)
            $memoryDifference = [Math]::Abs($afterMemory - $beforeMemory) / 1MB

            $memoryDifference | Should -BeLessThan 10  # Should release most memory
        }
    }
}
```

### Security Test Template
Validate security controls and input sanitization:

```powershell
Describe "Security Tests" -Tag "Security" {
    Context "Input Validation" {
        It "Should reject malicious input patterns" -TestCases @(
            @{ MaliciousInput = "'; DROP TABLE Users; --"; ExpectedError = '*invalid characters*' }
            @{ MaliciousInput = '../../../etc/passwd'; ExpectedError = '*invalid path*' }
            @{ MaliciousInput = '<script>alert("xss")</script>'; ExpectedError = '*invalid characters*' }
        ) {
            param($MaliciousInput, $ExpectedError)

            { Function-Name -ParameterName $MaliciousInput } | Should -Throw $ExpectedError
        }

        It "Should sanitize file paths" {
            $unsafePath = "..\..\Windows\System32\config"

            { Function-Name -FilePath $unsafePath } | Should -Throw "*invalid path*"
        }
    }

    Context "Credential Handling" {
        It "Should not expose credentials in logs" {
            $testCredential = New-Object PSCredential("testuser", (ConvertTo-SecureString "testpass" -AsPlainText -Force))

            # Capture verbose output
            $verboseOutput = Function-Name -Credential $testCredential -Verbose 4>&1

            # Ensure credentials are not exposed
            $verboseOutput -join ' ' | Should -Not -Match 'testuser'
            $verboseOutput -join ' ' | Should -Not -Match 'testpass'
        }

        It "Should handle invalid credentials gracefully" {
            $invalidCredential = New-Object PSCredential("invalid", (ConvertTo-SecureString "invalid" -AsPlainText -Force))

            { Function-Name -Credential $invalidCredential } | Should -Throw "*authentication*"
        }
    }
}
```

## Test Data and Mocking

### Test Data Management
Create reusable test data and fixtures:

```powershell
# TestHelpers/TestHelpers.ps1
function New-TestData {
    param(
        [string]$DataType = 'Default'
    )

    switch ($DataType) {
        'ServerList' {
            return @(
                @{ Name = 'SERVER01'; Environment = 'Production'; Status = 'Running' }
                @{ Name = 'SERVER02'; Environment = 'Development'; Status = 'Stopped' }
                @{ Name = 'SERVER03'; Environment = 'Testing'; Status = 'Running' }
            )
        }
        'Configuration' {
            return @{
                Environment = 'Testing'
                LogLevel = 'Verbose'
                Timeout = 30
                RetryCount = 3
            }
        }
        'Default' {
            return @{
                TestProperty = 'TestValue'
                TestNumber = 42
                TestDate = Get-Date
            }
        }
    }
}

function New-MockCredential {
    param([string]$Username = 'testuser')

    return New-Object PSCredential($Username, (ConvertTo-SecureString 'testpass' -AsPlainText -Force))
}
```

### Advanced Mocking Patterns
Implement sophisticated mocking strategies:

```powershell
# Context-aware mocking
BeforeAll {
    Mock External-API {
        param($Endpoint, $Method, $Data)

        switch ($Endpoint) {
            '/api/users' {
                if ($Method -eq 'GET') {
                    return @{ Users = @('User1', 'User2') }
                }
            }
            '/api/health' {
                return @{ Status = 'Healthy'; Timestamp = Get-Date }
            }
        }
    } -ModuleName ModuleName

    # Mock with parameter filters
    Mock Write-Log {
        # Only mock error logs for testing
    } -ModuleName ModuleName -ParameterFilter { $Level -eq 'Error' }
}
```

## Test Configuration and Execution

### Pester Configuration
Create standardized Pester configuration:

```powershell
# PesterConfiguration.psd1
@{
    Run = @{
        Path = @('./Tests/Unit', './Tests/Integration')
        PassThru = $true
        Throw = $true
    }

    Output = @{
        Verbosity = 'Detailed'
        StackTraceVerbosity = 'Filtered'
    }

    CodeCoverage = @{
        Enabled = $true
        Path = @('./Public/*.ps1', './Private/*.ps1')
        OutputFormat = 'JaCoCo'
        OutputPath = './Tests/Results/Coverage.xml'
        Threshold = 80
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './Tests/Results/TestResults.xml'
    }
}
```

### Test Execution Script
Generate comprehensive test runner:

```powershell
# Invoke-Tests.ps1
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Performance', 'Security', 'All')]
    [string]$TestType = 'All',
    [string]$OutputPath = './Tests/Results',
    [switch]$CodeCoverage,
    [switch]$PassThru
)

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force
}

# Load Pester configuration
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile './PesterConfiguration.psd1')

# Configure test execution based on type
switch ($TestType) {
    'Unit' {
        $config.Run.Path = @('./Tests/Unit')
        $config.Run.Tag = @('Unit')
    }
    'Integration' {
        $config.Run.Path = @('./Tests/Integration')
        $config.Run.Tag = @('Integration')
    }
    'Performance' {
        $config.Run.Path = @('./Tests/Performance')
        $config.Run.Tag = @('Performance')
    }
    'Security' {
        $config.Run.Path = @('./Tests/Security')
        $config.Run.Tag = @('Security')
    }
    'All' {
        $config.Run.Path = @('./Tests/Unit', './Tests/Integration', './Tests/Performance', './Tests/Security')
    }
}

# Configure code coverage
if ($CodeCoverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-$TestType.xml"
}

# Configure test results output
$config.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$TestType.xml"

# Execute tests
Write-Host "🧪 Executing $TestType tests..." -ForegroundColor Cyan
$result = Invoke-Pester -Configuration $config

# Generate summary report
Write-Host "`n📊 Test Execution Summary:" -ForegroundColor Green
Write-Host "  Total Tests: $($result.Tests.Count)"
Write-Host "  Passed: $($result.Tests.Passed.Count)" -ForegroundColor Green
Write-Host "  Failed: $($result.Tests.Failed.Count)" -ForegroundColor $(if ($result.Tests.Failed.Count -gt 0) { 'Red' } else { 'Green' })
Write-Host "  Duration: $($result.Duration)"

if ($CodeCoverage -and $result.CodeCoverage) {
    $coveragePercent = [math]::Round($result.CodeCoverage.CoveredPercent, 2)
    Write-Host "  Code Coverage: $coveragePercent%" -ForegroundColor $(if ($coveragePercent -ge 80) { 'Green' } else { 'Yellow' })
}

# Handle test failures
if ($result.Failed.Count -gt 0) {
    Write-Host "`n❌ Failed Tests:" -ForegroundColor Red
    foreach ($test in $result.Tests.Failed) {
        Write-Host "  - $($test.Name): $($test.ErrorRecord.Exception.Message)" -ForegroundColor Red
    }

    if (-not $PassThru) {
        exit 1
    }
}

if ($PassThru) {
    return $result
}
```

## Quality Gates and Standards

### Minimum Quality Requirements
Implement quality gates for test suites:

- **Unit Tests**: 100% of public functions must have unit tests
- **Code Coverage**: Minimum 80% coverage for production code
- **Test Execution**: All tests must pass before code integration
- **Performance**: Tests must complete within defined time limits
- **Security**: Security tests required for all input validation and credential handling

### CI/CD Integration Requirements
Ensure tests integrate with automated pipelines:

- **Test Results**: Export in NUnit XML format for CI/CD systems
- **Code Coverage**: Export in JaCoCo format for coverage tracking
- **Performance Baselines**: Track and alert on performance regressions
- **Security Validation**: Automated security test execution in pipelines

Generate comprehensive Pester test suites that follow enterprise testing standards, provide excellent coverage, and integrate seamlessly with CI/CD pipelines while maintaining the established troubleshooting documentation structure in `./Troubleshooting/` folders.