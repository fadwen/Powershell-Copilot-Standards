# Test Execution Guide

Targets **Pester 6.1+** on Windows PowerShell 5.1 or PowerShell 7.4+.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Comprehensive Test Runner Script

Create a standardized test execution script for consistent testing across environments:

```powershell
# Invoke-Tests.ps1
#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Performance', 'Security', 'All')]
    [string]$TestType = 'All',

    [ValidateSet('Development', 'CI', 'Production')]
    [string]$Environment = 'Development',

    [string]$OutputPath = './Tests/Results',
    [switch]$CodeCoverage,
    [switch]$PassThru,
    [switch]$ShowReport,
    [string[]]$Tag = @(),
    [string[]]$ExcludeTag = @(),

    # EXPERIMENTAL: run test files concurrently, one file per runspace.
    # Requires PowerShell 7+; falls back to sequential with a warning otherwise.
    [switch]$Parallel,
    [int]$ThrottleLimit = 0,  # 0 = use all available processors

    # EXPERIMENTAL: randomize file/block/test order to surface order dependence.
    [switch]$Shuffle,
    [int]$ShuffleSeed = 0     # 0 = new seed each run, printed at the start
)

begin {
    Write-Host "PowerShell Test Execution Framework" -ForegroundColor Cyan
    Write-Host "Test Type: $TestType | Environment: $Environment" -ForegroundColor Green

    # Pester 6.1 is required - Should-* assertions, New-ShouldAssertion, the parallel
    # runner, and Run.Shuffle are not all present in earlier versions
    $pester = Get-Module Pester -ListAvailable |
        Sort-Object Version -Descending | Select-Object -First 1

    if (-not $pester -or $pester.Version -lt [version]'6.1.0') {
        Write-Error "Pester 6.1+ is required (found: $(if ($pester) { $pester.Version } else { 'none' })). Install with: Install-Module Pester -MinimumVersion 6.1.0 -Force"
        exit 1
    }
    Import-Module Pester -MinimumVersion 6.1.0 -Force

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Import test configuration
    $configPath = Join-Path $PSScriptRoot "PesterConfiguration.$Environment.psd1"
    if (-not (Test-Path $configPath)) {
        $configPath = Join-Path $PSScriptRoot "PesterConfiguration.psd1"
    }

    if (Test-Path $configPath) {
        $configData = Import-PowerShellDataFile $configPath
        $config = New-PesterConfiguration -Hashtable $configData
    } else {
        $config = New-PesterConfiguration
    }
}

process {
    try {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

        # Configure test execution based on type
        switch ($TestType) {
            'Unit' {
                $config.Run.Path = @('./Tests/Unit')
                $config.Filter.Tag = @('Unit')
                Write-Host "Executing Unit Tests..." -ForegroundColor Yellow
            }
            'Integration' {
                $config.Run.Path = @('./Tests/Integration')
                $config.Filter.Tag = @('Integration')
                Write-Host "Executing Integration Tests..." -ForegroundColor Yellow
            }
            'Performance' {
                $config.Run.Path = @('./Tests/Performance')
                $config.Filter.Tag = @('Performance')
                Write-Host "Executing Performance Tests..." -ForegroundColor Yellow
            }
            'Security' {
                $config.Run.Path = @('./Tests/Security')
                $config.Filter.Tag = @('Security')
                Write-Host "Executing Security Tests..." -ForegroundColor Yellow
            }
            'All' {
                $config.Run.Path = @('./Tests/Unit', './Tests/Integration', './Tests/Performance', './Tests/Security')
                Write-Host "Executing All Tests..." -ForegroundColor Yellow
            }
        }

        # Apply additional tag filtering
        if ($Tag) {
            $config.Filter.Tag = @($config.Filter.Tag.Value) + $Tag
        }
        if ($ExcludeTag) {
            $config.Filter.ExcludeTag = $ExcludeTag
        }

        $config.Run.PassThru = $true

        # Configure code coverage
        if ($CodeCoverage) {
            $config.CodeCoverage.Enabled = $true
            $config.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-$TestType-$timestamp.xml"
            Write-Host "Code coverage enabled (profiler-based)" -ForegroundColor Green
        }

        # Configure parallel execution
        if ($Parallel) {
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                Write-Warning "Run.Parallel requires PowerShell 7+; running sequentially."
            }
            elseif ($TestType -in 'Performance', 'Integration') {
                Write-Warning "$TestType tests should not run in parallel; ignoring -Parallel."
            }
            else {
                $config.Run.Parallel = $true
                $config.Run.ParallelThrottleLimit = $ThrottleLimit
                $limitText = if ($ThrottleLimit -eq 0) { 'all processors' } else { "$ThrottleLimit files" }
                Write-Host "Parallel execution enabled (throttle: $limitText)" -ForegroundColor Green

                # Pester 6.1 collects coverage under parallel, but forces breakpoint mode
                # to do it - which is far slower per file than the profiler tracer.
                if ($CodeCoverage) {
                    Write-Warning "Coverage under -Parallel uses breakpoints, not the profiler. Expect it to be slower than a sequential coverage run."
                }
            }
        }

        # Configure shuffled execution order
        if ($Shuffle) {
            if ($TestType -eq 'Performance') {
                Write-Warning "Performance baselines assume a fixed order; ignoring -Shuffle."
            }
            else {
                $config.Run.Shuffle = $true
                if ($ShuffleSeed -ne 0) {
                    $config.Run.ShuffleSeed = $ShuffleSeed
                    Write-Host "Shuffled execution replaying seed $ShuffleSeed" -ForegroundColor Green
                } else {
                    Write-Host "Shuffled execution enabled (seed printed below)" -ForegroundColor Green
                }
            }
        }

        # Configure test results output
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$TestType-$timestamp.xml"

        # Set environment-specific verbosity
        if ($Environment -eq 'CI') {
            $config.Output.Verbosity = 'Normal'
            $config.Output.CIFormat = 'Auto'
        } else {
            $config.Output.Verbosity = 'Detailed'
        }

        # Execute tests
        $startTime = Get-Date
        Write-Host "Test execution started at $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

        $result = Invoke-Pester -Configuration $config

        $endTime = Get-Date
        $duration = $endTime - $startTime

        # Generate comprehensive summary
        Write-Host "`nTest Execution Summary:" -ForegroundColor Green
        Write-Host "  Environment: $Environment" -ForegroundColor Gray
        Write-Host "  Test Type:   $TestType" -ForegroundColor Gray
        Write-Host "  Duration:    $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor White
        Write-Host "  Passed:      $($result.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed:      $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  Skipped:     $($result.SkippedCount)" -ForegroundColor Yellow
        Write-Host "  Inconclusive: $($result.InconclusiveCount)" -ForegroundColor Yellow
        Write-Host "  Not Run:     $($result.NotRunCount)" -ForegroundColor Gray

        # Code coverage summary.
        # Pester 5/6 property names: CoveragePercent, CommandsExecutedCount,
        # CommandsAnalyzedCount. The Pester 4 names (CoveredPercent,
        # NumberOfCommandsExecuted) do not exist and silently return $null.
        if ($CodeCoverage -and $result.CodeCoverage) {
            $coveragePercent = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
            $coverageTarget  = $result.CodeCoverage.CoveragePercentTarget
            $coverageColor = if ($coveragePercent -ge $coverageTarget) { 'Green' }
                             elseif ($coveragePercent -ge ($coverageTarget * 0.75)) { 'Yellow' }
                             else { 'Red' }
            Write-Host "  Code Coverage: $coveragePercent% (target $coverageTarget%)" -ForegroundColor $coverageColor
            Write-Host "    Commands Covered: $($result.CodeCoverage.CommandsExecutedCount)" -ForegroundColor Gray
            Write-Host "    Commands Total:   $($result.CodeCoverage.CommandsAnalyzedCount)" -ForegroundColor Gray
            Write-Host "    Files Analyzed:   $($result.CodeCoverage.FilesAnalyzedCount)" -ForegroundColor Gray
        }

        # Performance summary for performance tests.
        # Test.Duration is a TimeSpan - use .TotalMilliseconds, not the raw object.
        if ($TestType -eq 'Performance' -or $TestType -eq 'All') {
            Write-Host "`nPerformance Summary:" -ForegroundColor Cyan
            $performanceTests = $result.Tests | Where-Object { $_.Tag -contains 'Performance' }
            if ($performanceTests) {
                $avgMs = ($performanceTests.Duration.TotalMilliseconds | Measure-Object -Average).Average
                Write-Host "  Average Test Duration: $([math]::Round($avgMs, 2))ms" -ForegroundColor Gray

                $slowTests = $performanceTests |
                    Where-Object { $_.Duration.TotalSeconds -gt 5 } |
                    Sort-Object { $_.Duration } -Descending
                if ($slowTests) {
                    Write-Host "  WARNING - Slow Tests (>5s):" -ForegroundColor Yellow
                    $slowTests | ForEach-Object {
                        Write-Host "    - $($_.ExpandedPath): $([math]::Round($_.Duration.TotalSeconds, 2))s" -ForegroundColor Yellow
                    }
                }
            }
        }

        # Failed test details
        if ($result.FailedCount -gt 0) {
            Write-Host "`nFailed Tests:" -ForegroundColor Red
            foreach ($test in $result.Failed) {
                Write-Host "  - $($test.ExpandedPath)" -ForegroundColor Red
                Write-Host "    Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor Red

                # Include troubleshooting hints
                $hint = Get-TroubleshootingHint -TestName $test.Name -ErrorRecord $test.ErrorRecord
                if ($hint) {
                    Write-Host "    Hint: $hint" -ForegroundColor Cyan
                }
            }
        }

        # Report containers that failed to discover. This is a v6 failure mode
        # (duplicate setup blocks, empty -ForEach, or a file that cannot be
        # discovered independently) and it does NOT show up in FailedCount -
        # a suite can report 0 failed tests while whole files never ran.
        if ($result.FailedContainersCount -gt 0) {
            Write-Host "`nFailed Containers (discovery or setup errors):" -ForegroundColor Red
            $result.FailedContainers | ForEach-Object {
                Write-Host "  - $($_.Item)" -ForegroundColor Red
                if ($_.ErrorRecord) {
                    Write-Host "    $($_.ErrorRecord.Exception.Message)" -ForegroundColor Red
                }
            }
        }

        # Generate test report
        if ($ShowReport) {
            $reportPath = Join-Path $OutputPath "TestReport-$TestType-$timestamp.html"
            New-TestReport -TestResult $result -OutputPath $reportPath -CodeCoverage:$CodeCoverage
            Write-Host "`nTest report generated: $reportPath" -ForegroundColor Green
        }

        # Export metrics for trending
        $metrics = @{
            TestType          = $TestType
            Environment       = $Environment
            Timestamp         = Get-Date -Format 'o'
            Duration          = $duration.TotalSeconds
            TotalTests        = $result.TotalCount
            PassedTests       = $result.PassedCount
            FailedTests       = $result.FailedCount
            SkippedTests      = $result.SkippedCount
            CodeCoverage      = if ($result.CodeCoverage) { $result.CodeCoverage.CoveragePercent } else { $null }
            Parallel          = [bool]$config.Run.Parallel.Value
            # Record the seed. A shuffle failure is only reproducible if the seed
            # outlives the console log.
            Shuffle           = [bool]$config.Run.Shuffle.Value
            ShuffleSeed       = $result.Configuration.Run.ShuffleSeed.Value
            PesterVersion     = $pester.Version.ToString()
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            Platform          = $PSVersionTable.Platform
        }

        $metricsPath = Join-Path $OutputPath "TestMetrics-$TestType-$timestamp.json"
        $metrics | ConvertTo-Json | Out-File $metricsPath -Encoding UTF8

        # Handle CI/CD integration
        if ($Environment -eq 'CI') {
            # GitHub Actions step outputs.
            # ::set-output was disabled by GitHub in 2023 - write to $GITHUB_OUTPUT.
            if ($env:GITHUB_OUTPUT) {
                "total-tests=$($result.TotalCount)"   | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
                "passed-tests=$($result.PassedCount)" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
                "failed-tests=$($result.FailedCount)" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
                if ($result.CodeCoverage) {
                    "code-coverage=$($result.CodeCoverage.CoveragePercent)" | Out-File $env:GITHUB_OUTPUT -Append -Encoding utf8
                }
            }

            # GitHub Actions job summary
            if ($env:GITHUB_STEP_SUMMARY) {
                $summary = @(
                    "## Test Results - $TestType"
                    ''
                    '| Metric | Value |'
                    '| --- | --- |'
                    "| Total | $($result.TotalCount) |"
                    "| Passed | $($result.PassedCount) |"
                    "| Failed | $($result.FailedCount) |"
                    "| Skipped | $($result.SkippedCount) |"
                ) -join "`n"
                $summary | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
            }

            # Azure DevOps variables
            if ($env:BUILD_BUILDID) {
                Write-Host "##vso[task.setvariable variable=TotalTests]$($result.TotalCount)"
                Write-Host "##vso[task.setvariable variable=PassedTests]$($result.PassedCount)"
                Write-Host "##vso[task.setvariable variable=FailedTests]$($result.FailedCount)"
                if ($result.CodeCoverage) {
                    Write-Host "##vso[task.setvariable variable=CodeCoverage]$($result.CodeCoverage.CoveragePercent)"
                }
            }
        }

        # Return result for further processing
        if ($PassThru) {
            return $result
        }

        # Exit with appropriate code. Check container failures too - a file that
        # failed discovery contributes 0 to FailedCount.
        if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
            Write-Host "`nTests failed. Exiting with code 1." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "`nAll tests passed successfully." -ForegroundColor Green
            exit 0
        }
    }
    catch {
        Write-Host "`nTest execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray

        if ($PassThru) {
            throw
        } else {
            exit 1
        }
    }
}

end {
    Write-Host "`nCleaning up test environment..." -ForegroundColor Gray
}

# Helper functions
function Get-TroubleshootingHint {
    param(
        [string]$TestName,
        # Do not name this parameter $Error - that shadows the automatic variable
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $hints = [ordered]@{
        'Connection'     = 'Check network connectivity and firewall settings. See ./Troubleshooting/Connectivity/'
        'Authentication' = 'Verify credentials and permissions. See ./Troubleshooting/Security/'
        'Permission'     = 'Run as administrator or check file permissions. See ./Troubleshooting/Security/'
        'Memory'         = 'Increase available memory or optimize code. See ./Troubleshooting/Performance/'
        'Timeout'        = 'Increase timeout values or optimize performance. See ./Troubleshooting/Performance/'
        'not recognized' = 'Command not found. In Pester 6 each test file must import its own modules - check BeforeAll/BeforeDiscovery.'
        'ForEach'        = 'Empty -ForEach fails discovery in Pester 6. Build test data in BeforeDiscovery, not BeforeAll.'
        'already defined' = 'Duplicate BeforeAll/BeforeEach/AfterAll/AfterEach in one block throws in Pester 6. Merge them.'
        'Assert-Mock'    = 'Assert-MockCalled was removed in Pester 6. Use Should -Invoke or Should-Invoke.'
    }

    foreach ($keyword in $hints.Keys) {
        if ($ErrorRecord.Exception.Message -match [regex]::Escape($keyword) -or $TestName -match [regex]::Escape($keyword)) {
            return $hints[$keyword]
        }
    }

    return "Check ./Troubleshooting/ folder for detailed guidance"
}

function New-TestReport {
    param(
        [object]$TestResult,
        [string]$OutputPath,
        [switch]$CodeCoverage
    )

    $rows = foreach ($test in $TestResult.Tests) {
        $resultClass = switch ($test.Result) {
            'Passed' { 'test-passed' }
            'Failed' { 'test-failed' }
            default  { '' }
        }
        $errorMessage = if ($test.ErrorRecord) {
            [System.Web.HttpUtility]::HtmlEncode($test.ErrorRecord.Exception.Message)
        } else { '' }
        $name = [System.Web.HttpUtility]::HtmlEncode($test.ExpandedPath)

        @"
        <tr class="$resultClass">
            <td>$name</td>
            <td class="$($test.Result.ToLower())">$($test.Result)</td>
            <td>$([math]::Round($test.Duration.TotalMilliseconds, 2))ms</td>
            <td>$errorMessage</td>
        </tr>
"@
    }

    $coverageRow = if ($CodeCoverage -and $TestResult.CodeCoverage) {
        "<p><strong>Code Coverage:</strong> $([math]::Round($TestResult.CodeCoverage.CoveragePercent, 2))%</p>"
    } else { '' }

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>PowerShell Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .test-failed { background-color: #ffebee; }
        .test-passed { background-color: #e8f5e8; }
    </style>
</head>
<body>
    <h1>PowerShell Test Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Tests:</strong> $($TestResult.TotalCount)</p>
        <p><strong class="passed">Passed:</strong> $($TestResult.PassedCount)</p>
        <p><strong class="failed">Failed:</strong> $($TestResult.FailedCount)</p>
        <p><strong class="skipped">Skipped:</strong> $($TestResult.SkippedCount)</p>
        <p><strong>Duration:</strong> $($TestResult.Duration)</p>
        $coverageRow
    </div>
    <h2>Test Results</h2>
    <table>
        <tr>
            <th>Test Name</th>
            <th>Result</th>
            <th>Duration</th>
            <th>Error Message</th>
        </tr>
$($rows -join "`n")
    </table>
</body>
</html>
"@

    $html | Out-File $OutputPath -Encoding UTF8
}
```

`New-TestReport` uses `[System.Web.HttpUtility]::HtmlEncode`. On PowerShell 7 add
`Add-Type -AssemblyName System.Web` first, or substitute your own encoder - test names and error
messages routinely contain `<`, `>`, and `&` which would otherwise corrupt the report.

## Result Object Reference

Pester 6 keeps the v5 result object. The property names below are the ones that exist - the Pester 4
names in older guidance return `$null` silently.

| Use | Property |
| --- | --- |
| Counts | `TotalCount`, `PassedCount`, `FailedCount`, `SkippedCount`, `InconclusiveCount`, `NotRunCount` |
| Test collections | `Tests`, `Passed`, `Failed`, `Skipped`, `Inconclusive`, `NotRun` |
| Per-file results | `Containers` (each has `Item`, `Result`, `Passed`, `ErrorRecord`) |
| Discovery failures | `FailedContainers`, `FailedContainersCount` |
| Block-level failures | `FailedBlocks`, `FailedBlocksCount` |
| Coverage percent | `CodeCoverage.CoveragePercent` (**not** `CoveredPercent`) |
| Coverage target | `CodeCoverage.CoveragePercentTarget` |
| Commands covered | `CodeCoverage.CommandsExecutedCount` (**not** `NumberOfCommandsExecuted`) |
| Commands total | `CodeCoverage.CommandsAnalyzedCount` (**not** `NumberOfCommandsAnalyzed`) |
| Missed commands | `CodeCoverage.CommandsMissed` |
| Test duration | `$test.Duration` - a `TimeSpan`; use `.TotalMilliseconds` |

`Duration` is a `TimeSpan`. Comparing it against a raw number (`$_.Duration -gt 5000`) does not do
what it looks like - use `$_.Duration.TotalMilliseconds -gt 5000`.

Pester 6 reports a **single duration** per test instead of the v5 `user|framework` split.

**Always check `FailedContainersCount` alongside `FailedCount`.** A file that fails discovery
contributes nothing to `FailedCount`, so a gate that only inspects `FailedCount` reports success
while entire test files never ran. This is the most likely way a v6 upgrade passes CI while silently
losing coverage.

## Quick Execution Commands

### Development Testing

```powershell
# Quick unit tests
.\Invoke-Tests.ps1 -TestType Unit -Environment Development

# Unit tests with coverage
.\Invoke-Tests.ps1 -TestType Unit -CodeCoverage -ShowReport

# Specific tags
.\Invoke-Tests.ps1 -Tag 'Critical' -ExcludeTag 'Slow'

# Fast feedback: unit tests in parallel, no coverage
.\Invoke-Tests.ps1 -TestType Unit -Parallel

# Surface order dependence, then replay the order that broke
.\Invoke-Tests.ps1 -TestType Unit -Shuffle
.\Invoke-Tests.ps1 -TestType Unit -Shuffle -ShuffleSeed 852659930
```

### CI/CD Pipeline Integration

```powershell
# Full CI test suite
.\Invoke-Tests.ps1 -TestType All -Environment CI -CodeCoverage

# Performance testing only
.\Invoke-Tests.ps1 -TestType Performance -Environment CI

# Security validation
.\Invoke-Tests.ps1 -TestType Security -Environment CI
```

## Parallel Test Execution (Experimental)

Pester 6 runs test **files** concurrently, one file per runspace, via PowerShell 7+
`ForEach-Object -Parallel`. On a multi-core machine this cuts wall-clock time substantially for
large suites.

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests/Unit'
$config.Run.Parallel = $true
$config.Run.ParallelThrottleLimit = 4   # 0 (default) uses all processors
Invoke-Pester -Configuration $config
```

```powershell
# Via the runner
.\Invoke-Tests.ps1 -TestType Unit -Parallel -ThrottleLimit 4
```

### When It Falls Back to Sequential

The run keeps working but emits a **warning** when:

| Condition | Reason |
| --- | --- |
| Windows PowerShell 5.1 | `ForEach-Object -Parallel` requires PowerShell 7+ |
| `ScriptBlock` containers | In-memory containers cannot cross runspaces |
| `Run.SkipRemainingOnFailure = 'Run'` | A cross-file stop cannot span runspaces |

When every file opts out with `#pester:no-parallel` the run is simply sequential and no warning is
printed - there is nothing left to parallelize.

### Coverage Under Parallel

Pester 6.0 collected no coverage in a parallel run. **6.1 collects it**: each worker measures the
same locations and the parent merges the per-location hits, adding the coverage of any
`#pester:no-parallel` files it ran in-session, into a single report.

The catch is that a parallel run forces **breakpoint-based** coverage, because the profiler tracer
keeps its state in a process-global static and is not concurrency-safe.
`CodeCoverage.UseBreakpoints = $false` is ignored on that path. Breakpoint coverage is much slower
per file, so parallel-plus-coverage can easily be slower overall than sequential-plus-profiler.

Splitting into **two CI jobs** is still the recommendation - a fast parallel job without coverage for
feedback, and a sequential job with the profiler for the coverage gate - but it is now a performance
choice you can measure rather than a hard requirement.

### Which Files to Opt Out

Add `#pester:no-parallel` at the top of any file that cannot share the machine:

```powershell
#pester:no-parallel
Describe 'Performance-Baseline' -Tag 'Performance' {
}
```

- **Performance tests** - timing measurements are meaningless under CPU contention
- **Integration tests** - shared databases, fixed ports, live endpoints
- Tests mutating global state (environment variables, the registry, the working directory)

Opted-out files run in the parent session on the serial path, with shared session state and live
output, while everything else runs in parallel.

### Requirements and Guarantees

Parallel needs **file-based** containers - `Run.Path`, or `New-PesterContainer -Path`, including
parametrized files built with `-Data` (each file's data reaches its worker, so its `param()` block
binds exactly as in a serial run).

Each worker runs silently and the parent **replays** every file's output in discovery order,
emitting the same plugin-event sequence as a serial run. Console output, the `TestResult` report,
and IDE adapters behave identically - only concurrency differs.

The run's total `Duration` becomes the orchestrator's elapsed time rather than the sum of the files,
and per-phase run totals (user, framework, discovery) are blank. That breakdown is still reported on
each container.

### Prerequisite: Self-Contained Files

Parallel only works if each file can be discovered and run on its own, because each worker starts
from a **clean runspace**. Put shared bootstrap in a `Pester.BeforeContainer.ps1` at the repository
root, which Pester dot-sources before every file in both serial and parallel runs:

```powershell
# Pester.BeforeContainer.ps1, at the repository root
. "$PSScriptRoot/Tests/TestHelpers/Bootstrap.ps1"
```

The `Run.BeforeContainer` option that also did this was **removed in 6.1**. If a CI job sets it, the
assignment now throws.

The file is only picked up from `Run.RepoRoot`, which is resolved from the .NET process working
directory - not `$PWD` - so set it explicitly when the run does not start at the repository root:

```powershell
$config.Run.RepoRoot = $PSScriptRoot
```

Validate isolation before enabling parallel - run a single file on its own:

```powershell
Invoke-Pester -Path ./Tests/Unit/Public/Get-Thing.Tests.ps1
```

If it only passes as part of a full run, it is not self-contained.

## Shuffled Test Order (Experimental)

New in 6.1. `Run.Shuffle` reorders the test files, and the blocks and tests inside them, so a suite
that depends on declaration order fails instead of passing by luck:

```powershell
$config = New-PesterConfiguration
$config.Run.Path    = './Tests/Unit'
$config.Run.Shuffle = $true
Invoke-Pester -Configuration $config
```

```powershell
# Via the runner
.\Invoke-Tests.ps1 -TestType Unit -Shuffle
```

Reordering happens only within a level - a test never leaves its `Context`. The run prints the seed
it picked and records it on the result:

```text
Shuffling execution order using seed 852659930. Set 'Run.ShuffleSeed = 852659930' to repeat this order.
```

```powershell
$result.Configuration.Run.ShuffleSeed.Value    # the seed this run actually used
$config.Run.ShuffleSeed = 852659930            # replay that exact order
```

Order dependence is the failure mode this finds, and it is one the per-file isolation model in
Pester 6 already narrows: files no longer share discovery-time state, so what is left is order
dependence _within_ a file - a `Describe` that leaves a `$script:` variable another one reads, a
`BeforeAll` that creates a fixture a later `Context` mutates.

### Reading a Shuffled Failure

A failure that appears only under shuffle is a real defect in the tests, not a Pester problem. Work
it in this order:

1. Capture the seed from the run output. Without it the ordering is not reproducible.
2. Re-run with `Run.ShuffleSeed` set to that value and confirm the failure repeats.
3. Find the shared state. It is nearly always a `$script:` variable, a file left on disk outside
   `TestDrive`, an environment variable, or a mock counter read across blocks.
4. Fix the test, not the order. Move setup into the block that needs it, or reset state in
   `AfterEach`.

A file whose blocks genuinely must run in sequence opts out with a directive, parsed the same way as
`#pester:no-parallel`:

```powershell
#pester:no-shuffle
Describe 'ordered migration steps' -Tag 'Integration' {
}
```

Treat that directive the way you treat `#pester:no-parallel`: reasonable for a sequential
integration script, a smell in a unit test file.

`Run.Shuffle` is experimental and may change. It affects ordering only - never which tests run, nor
how filters apply.

## Test Execution Best Practices

### Pre-Test Validation

```powershell
# Validate environment before testing
function Test-TestEnvironment {
    $issues = @()

    # Check PowerShell version - Pester 6 requires 5.1 or 7.4+
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1) {
        $issues += "Windows PowerShell 5.1+ required (found $psVersion)"
    }
    elseif ($psVersion.Major -eq 6 -or ($psVersion.Major -eq 7 -and $psVersion -lt [version]'7.4')) {
        $issues += "PowerShell 7.4+ required (found $psVersion). Pester 6 dropped support for 6.x and early 7.x."
    }

    # Check Pester version
    $pester = Get-Module Pester -ListAvailable |
        Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pester) {
        $issues += "Required module missing: Pester"
    } elseif ($pester.Version -lt [version]'6.1.0') {
        $issues += "Pester 6.1+ required (found $($pester.Version))"
    }

    # Check test data availability
    if (-not (Test-Path './Tests/TestData')) {
        $issues += "Test data directory missing"
    }

    return @{
        Valid  = $issues.Count -eq 0
        Issues = $issues
    }
}
```

### Structural Validation (Discovery-Only Pass)

Run discovery without executing anything. This is fast and catches the v6 structural breakages -
duplicate setup blocks, empty `-ForEach` sets, files that cannot be discovered independently:

```powershell
function Test-SuiteStructure {
    param([string]$Path = './Tests')

    $config = New-PesterConfiguration
    $config.Run.Path = $Path
    $config.Run.SkipRun = $true
    $config.Run.PassThru = $true
    $config.Output.Verbosity = 'Normal'

    $result = Invoke-Pester -Configuration $config

    $failed = $result.Containers | Where-Object { -not $_.Passed }
    if ($failed) {
        $failed | ForEach-Object { Write-Error "Discovery failed: $($_.Item)" }
        throw "$($failed.Count) file(s) failed discovery"
    }

    Write-Host "Discovered $($result.TotalCount) tests across $($result.Containers.Count) files"
    return $result
}
```

Run this as the first CI step. A discovery failure is cheap to find here and confusing to diagnose
inside a full run.

### Tagging Audit

```powershell
# Fail the build if any test escaped the tagging convention
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Filter.Tag = 'None'     # reserved value: tests with NO tags
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'

$result = Invoke-Pester -Configuration $config

# ShouldRun is the flag Filter.Tag sets, so it is the only count that reflects the filter.
# TotalCount ignores it and reports everything discovered, which would fail every non-empty
# suite; PassedCount only counts untagged tests that ran AND passed, and Run.SkipRun means
# nothing runs, so it is always 0. Both were verified against Pester 6.1.0.
$untagged = @($result.Tests | Where-Object ShouldRun)
if ($untagged.Count -gt 0) {
    $untagged | ForEach-Object { Write-Host "::error::Untagged test: $($_.ExpandedPath)" }
    throw "$($untagged.Count) test(s) have no tag."
}
```

### Coverage Gate

```powershell
# CoveragePercentTarget sets the reported target; it does not fail the run.
# Enforce the gate yourself.
$result = Invoke-Pester -Configuration $config
if ($result.CodeCoverage) {
    $actual = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
    $target = $result.CodeCoverage.CoveragePercentTarget
    if ($actual -lt $target) {
        Write-Host "Uncovered commands:"
        $result.CodeCoverage.CommandsMissed |
            Group-Object File |
            ForEach-Object { Write-Host "  $($_.Name): $($_.Count) commands" }
        throw "Code coverage $actual% is below the $target% target"
    }
}
```

### Post-Test Cleanup

```powershell
# Clean up test artifacts
function Clear-TestArtifacts {
    Get-ChildItem -Path $env:TEMP -Filter "PesterTest*" -Recurse -ErrorAction SilentlyContinue |
        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

    # Clean up test databases
    if (Test-Path './Tests/TestData/temp.db') {
        Remove-Item './Tests/TestData/temp.db' -Force
    }
}
```

### Test Result Analysis

```powershell
# Analyze test trends
function Get-TestTrends {
    param([string]$ResultsPath = './Tests/Results')

    Get-ChildItem -Path $ResultsPath -Filter "TestMetrics-*.json" |
        ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json } |
        Sort-Object Timestamp
}
```

### Converting Results to Other Formats

`TestResult` writes one format per run. Convert the result object for additional formats:

```powershell
$config.Run.PassThru = $true
$result = Invoke-Pester -Configuration $config

Export-NUnitReport -Result $result -Path './Tests/Results/NUnit.xml'
Export-JUnitReport -Result $result -Path './Tests/Results/JUnit.xml'
```
