# Unit Test Template

Targets **Pester 6.1+**. Uses the `Should-*` assertion syntax - see
[Assertion Guide](./assertion-guide.md) for the full reference and the v5 mapping table.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Standard Unit Test Structure

> Complete passing implementations of this template:
> [Module-Structure-Example/Tests](../../../Documentation/Examples/Module-Structure-Example/Tests/)
> and
> [Testing-Examples](../../../Documentation/Examples/Testing-Examples/).

Use this template for all unit tests:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }

BeforeDiscovery {
    # Pester 6 discovers and runs one file at a time, so this file must set up
    # anything it needs at DISCOVERY time - it cannot rely on another file.
    # Only needed when -ForEach data comes from the module itself.
    $ModulePath = Join-Path $PSScriptRoot '..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force
}

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
        It "Should accept valid input: <TestValue>" -ForEach @(
            @{ TestValue = 'ValidValue1'; Expected = 'ExpectedResult1' }
            @{ TestValue = 'ValidValue2'; Expected = 'ExpectedResult2' }
            @{ TestValue = 'ValidValue3'; Expected = 'ExpectedResult3' }
        ) {
            Function-Name -ParameterName $TestValue | Should-Be $Expected
        }

        It "Should reject invalid input: <Description>" -ForEach @(
            @{ Description = 'null';    InvalidInput = $null; ExpectedError = '*cannot be null*' }
            @{ Description = 'empty';   InvalidInput = '';    ExpectedError = '*cannot be empty*' }
            @{ Description = 'symbols'; InvalidInput = 'Invalid@#$'; ExpectedError = '*invalid characters*' }
        ) {
            { Function-Name -ParameterName $InvalidInput } |
                Should-Throw -ExceptionMessage $ExpectedError
        }

        It "Should support pipeline input" {
            $results = @('Value1', 'Value2', 'Value3') | Function-Name
            $results | Should-BeCollection -Count 3
        }

        It "Should declare ParameterName as a mandatory string" {
            Get-Command Function-Name |
                Should-HaveParameter -ParameterName ParameterName -Type ([string]) -Mandatory
        }
    }

    Context "Core Functionality" {
        BeforeEach {
            # Set up mocks for each test. Only ONE BeforeEach per block - Pester 6 throws on duplicates.
            Mock External-Dependency {
                @{ Status = 'Success'; Data = 'MockedData' }
            } -ModuleName ModuleName

            Mock Get-ExternalResource {
                [PSCustomObject]@{
                    Name  = 'TestResource'
                    Value = 'TestValue'
                }
            } -ModuleName ModuleName
        }

        It "Should return expected object structure" {
            $result = Function-Name -ParameterName 'TestValue'

            $result | Should-NotBeNull
            $result | Should-HaveType ([PSCustomObject])
            $result.PropertyName | Should-Be 'ExpectedValue'
        }

        It "Should return the full expected shape" {
            # Prefer one deep comparison over a run of property assertions.
            # -ExcludePathsNotOnExpected ignores properties absent from $expected,
            # so adding a new field to the output will not break this test.
            $result = Function-Name -ParameterName 'TestValue'

            $result | Should-BeEquivalent ([PSCustomObject]@{
                Name   = 'TestResource'
                Status = 'Processed'
            }) -ExcludePathsNotOnExpected
        }

        It "Should call external dependencies with correct parameters" {
            Function-Name -ParameterName 'TestValue'

            Should-Invoke External-Dependency -Times 1 -Exactly -ModuleName ModuleName -ParameterFilter {
                $Parameter -eq 'TestValue'
            }
        }

        It "Should handle multiple items correctly" {
            $results = Function-Name -ParameterName @('Item1', 'Item2', 'Item3')

            $results | Should-BeCollection -Count 3
            $results | Should-All { $_.Status -eq 'Processed' }
        }
    }

    Context "Error Handling" {
        It "Should handle external dependency failures gracefully" {
            Mock External-Dependency {
                throw 'External service unavailable'
            } -ModuleName ModuleName

            { Function-Name -ParameterName 'TestValue' } |
                Should-Throw -ExceptionMessage '*External service unavailable*'
        }

        It "Should surface a typed error for connection failures" {
            Mock External-Dependency {
                throw [System.TimeoutException]::new('Connection timeout')
            } -ModuleName ModuleName

            # Assert on the type, not on message text you control and change often
            { Function-Name -ParameterName 'TestValue' -ErrorAction Stop } |
                Should-Throw -ExceptionType ([System.TimeoutException])
        }

        It "Should continue processing other items when one fails" {
            Mock External-Dependency {
                if ($Parameter -eq 'FailingItem') {
                    throw 'Item processing failed'
                }
                @{ Status = 'Success' }
            } -ModuleName ModuleName

            $results = Function-Name -ParameterName @('GoodItem1', 'FailingItem', 'GoodItem2') -ErrorAction SilentlyContinue

            # Should process the good items despite one failure
            @($results | Where-Object { $_.Status -eq 'Success' }) | Should-BeCollection -Count 2
        }

        It "Should not call the downstream writer when validation fails" {
            Mock Write-Result { } -ModuleName ModuleName

            { Function-Name -ParameterName '' } | Should-Throw

            Should-NotInvoke Write-Result -ModuleName ModuleName
        }
    }

    Context "Performance Requirements" {
        It "Should complete within acceptable time limits" {
            { Function-Name -ParameterName 'TestValue' } | Should-BeFasterThan '5s'
        }

        It "Should scale linearly with input size" {
            $smallTime = Measure-Command { Function-Name -ParameterName (1..10) }
            $largeTime = Measure-Command { Function-Name -ParameterName (1..100) }

            # Large input should not be more than 15x slower (allows for overhead)
            $scalingRatio = $largeTime.TotalMilliseconds / $smallTime.TotalMilliseconds
            $scalingRatio | Should-BeLessThan 15
        }
    }
}
```

## Pester 6 Authoring Rules

### One setup block per scope

Pester 6 **throws** on duplicate `BeforeAll`, `BeforeEach`, `AfterAll`, or `AfterEach` in the same
block. This catches a common copy-paste mistake. Merge them into one.

### No `param()` block in `It`

Data from `-ForEach` / `-TestCases` is injected as variables automatically. Do not add a `param()`
block - it is unnecessary and invites the `$Input` bug below.

```powershell
# WRONG - $Input is an automatic variable and will not hold your test data
It 'test <Input>' -ForEach @(@{ Input = 'a' }) {
    param($Input)
    ...
}

# RIGHT - name the key something else; no param() needed
It 'test <TestValue>' -ForEach @(@{ TestValue = 'a' }) {
    $TestValue | Should-Be 'a'
}
```

Never use `Input`, `Args`, `Error`, `Host`, `Matches`, or `PSItem` as `-ForEach` keys - they collide
with PowerShell automatic variables.

### `-ForEach` must not be empty

`Run.FailOnNullOrEmptyForEach` is on by default, so a `-ForEach` that evaluates to `$null` or `@()`
**fails discovery**. When an empty set is legitimate, opt out explicitly:

```powershell
It 'handles <Name>' -ForEach $cases -AllowNullOrEmptyForEach {
    ...
}
```

Prefer fixing the generator over adding the switch - an empty test case list usually means the data
source silently returned nothing.

### Test names expand only `<...>`

Everything outside `<...>` stays literal, including backticks, `$`, and quotes. Inside `<...>` the
content is evaluated as a full PowerShell expression and rendered through Pester's formatter:

```powershell
It 'returns <Expected> for <TestValue>'          # property references
It 'totals <($a + $b)>'                          # full expressions work in v6
It 'handles a literal `<placeholder>'            # escape the bracket for literal text
```

### `-Focus` and `-Pending` are gone

Use `-Skip`, tags, or the `Filter` configuration to select which tests run. Use
`Set-ItResult -Skipped` or `-Inconclusive` instead of `-Pending`.

## Test Context Guidelines

### Parameter Validation Context

Test all parameter validation scenarios:

- Valid input variations
- Invalid input rejection
- Pipeline support
- Parameter binding and metadata (`Should-HaveParameter`)
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
- Downstream calls _not_ made on failure (`Should-NotInvoke`)

### Performance Requirements Context

Establish performance baselines:

- Execution time limits (`Should-BeFasterThan`)
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

### Common Assertions

| Intent | Assertion |
| --- | --- |
| Exact value | `Should-Be` |
| String with options | `Should-BeString -CaseSensitive` / `-TrimWhitespace` |
| Type validation | `Should-HaveType ([T])` |
| Pattern matching | `Should-MatchString 'regex'` |
| Error validation | `Should-Throw -ExceptionType` / `-ExceptionMessage` |
| Performance limits | `Should-BeFasterThan '5s'` |
| Collection size | `Should-BeCollection -Count 3` |
| Every item matches | `Should-All { ... }` |
| Whole-object shape | `Should-BeEquivalent -ExcludePathsNotOnExpected` |
| Mock was called | `Should-Invoke -Times 1 -Exactly` |
| Mock was not called | `Should-NotInvoke` |

There is no `Should-NotThrow`. Call the code directly - an unhandled exception fails the test.

`Should -BeNullOrEmpty` has no single `Should-*` equivalent. Pick the one you mean: `Should-BeNull`,
`Should-BeEmptyString`, or `Should-BeFalsy`.
