# Unit Test Template

## Standard Unit Test Structure

Use this template for all unit tests:

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

## Test Context Guidelines

### Parameter Validation Context
Test all parameter validation scenarios:
- Valid input variations
- Invalid input rejection
- Pipeline support
- Parameter binding
- Mandatory parameter enforcement

### Core Functionality Context
Test the main business logic:
- Expected return values and types
- Object structure validation
- External dependency interaction
- Multiple item processing
- Business rule compliance

### Error Handling Context
Validate error scenarios:
- External dependency failures
- Invalid state handling
- Meaningful error messages
- Graceful degradation
- Recovery mechanisms

### Performance Requirements Context
Establish performance baselines:
- Execution time limits
- Scaling characteristics
- Memory usage patterns
- Resource cleanup
- Bottleneck identification

## Assertion Guidelines

### Comprehensive Assertions
- Test return values and types
- Verify object properties and structure
- Validate external dependency calls
- Check error conditions and messages
- Measure performance characteristics

### Should Operators
- `Should -Be`: Exact value comparison
- `Should -BeOfType`: Type validation
- `Should -Match`: Pattern matching
- `Should -Throw`: Error validation
- `Should -BeLessThan`: Performance limits
