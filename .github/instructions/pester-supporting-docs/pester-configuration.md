# Pester Configuration Guide

Targets **Pester 6.1+**. All settings below were verified against the `PesterConfiguration` object.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Standard Pester Configuration

Use this standardized configuration for consistent test execution:

```powershell
# PesterConfiguration.psd1
@{
    Run = @{
        Path        = @('./Tests/Unit', './Tests/Integration')
        ExcludePath = @()
        PassThru    = $true
        Throw       = $true
        SkipRun     = $false

        # Pester 6: empty -ForEach fails discovery. Keep on; opt out per test with
        # -AllowNullOrEmptyForEach where an empty set is legitimately expected.
        FailOnNullOrEmptyForEach = $true

        # None | Run | Container | Block
        SkipRemainingOnFailure = 'None'

        # EXPERIMENTAL. Off by default. See "Parallel Execution" below.
        Parallel              = $false
        ParallelThrottleLimit = 0

        # EXPERIMENTAL. Off by default. See "Shuffled Test Order" below.
        Shuffle     = $false
        ShuffleSeed = 0                    # 0 picks a new seed per run and prints it
    }

    Output = @{
        Verbosity           = 'Detailed'
        StackTraceVerbosity = 'Filtered'   # None | FirstLine | Filtered | Full
        CIFormat            = 'Auto'       # Auto | AzureDevops | GithubActions
        CILogLevel          = 'Error'
        CIDebugOutput       = 'Auto'       # Auto | None - surface verbose/debug on CI debug runs
        RenderMode          = 'Auto'       # Auto | Ansi | ConsoleColor | Plaintext
        ShowTags            = $false       # append [Tags: ...] to each output line
    }

    Mock = @{
        # EXPERIMENTAL. Off by default. See "Global Mocks" below.
        Global = $false
    }

    CodeCoverage = @{
        Enabled              = $true
        Path                 = @('./Public/*.ps1', './Private/*.ps1', './Classes/*.ps1')
        OutputFormat         = 'JaCoCo'    # JaCoCo | Cobertura
        OutputPath           = './Tests/Results/Coverage.xml'
        OutputEncoding       = 'UTF8'
        CoveragePercentTarget = 80         # NOT "Threshold" - that setting does not exist
        UseBreakpoints       = $false      # $false = profiler-based (v6 default, much faster)
        SingleHitBreakpoints = $true
        ExcludeTests         = $true       # keep test files out of the coverage numbers
        RecursePaths         = $true
        ReportRoot           = ''          # defaults to Run.RepoRoot
    }

    TestResult = @{
        Enabled        = $true
        OutputFormat   = 'NUnitXml'        # NUnitXml | NUnit2.5 | NUnit3 | JUnitXml
        OutputPath     = './Tests/Results/TestResults.xml'
        OutputEncoding = 'UTF8'
        TestSuiteName  = 'PowerShell Tests'
    }

    Should = @{
        ErrorAction = 'Stop'               # 'Continue' enables soft assertions
        DisableV5   = $false               # $true makes `Should -Be` throw
    }

    Debug = @{
        ShowFullErrors         = $false
        WriteDebugMessages     = $false
        WriteDebugMessagesFrom = @()
        ShowNavigationMarkers  = $false
        ShowStartMarkers       = $false    # v6: marks when each test starts
        ReturnRawResultObject  = $false
    }

    Filter = @{
        Tag        = @()
        ExcludeTag = @()
        Line       = @()
        ExcludeLine = @()
        FullName   = @()
    }
}
```

### Settings That Do Not Exist

These appear in older guidance and in a lot of blog posts. They are not real and are silently
ignored when set via a hashtable:

| Not a setting | Use instead |
| --- | --- |
| `CodeCoverage.Threshold` | `CodeCoverage.CoveragePercentTarget` |
| `CodeCoverage.PerFileThreshold` | No equivalent - enforce per-file in your own gate |
| `CodeCoverage.ExcludePath` | `Run.ExcludePath`, or narrow `CodeCoverage.Path` |
| `TestResult.OutputFormat = 'VSTest'` | `NUnitXml`, `NUnit2.5`, `NUnit3`, or `JUnitXml` |
| `CodeCoverage.OutputFormat = 'CoverageGutters'` | `JaCoCo` - removed in v6, see below |

`CoveragePercentTarget` sets the target Pester reports against. It does **not** fail the run on its
own - enforce the gate yourself:

```powershell
$result = Invoke-Pester -Configuration $config
$covered = $result.CodeCoverage.CoveragePercent
if ($covered -lt $config.CodeCoverage.CoveragePercentTarget.Value) {
    throw "Code coverage $([math]::Round($covered, 2))% is below the $($config.CodeCoverage.CoveragePercentTarget.Value)% target"
}
```

### Auto-Enable Behavior

In Pester 6, `TestResult` and `CodeCoverage` **auto-enable** when you set any of their non-default
options. You can no longer silently configure a report that never gets written. Setting
`CodeCoverage.Path` is enough to turn coverage on.

## Environment-Specific Configurations

### Development Configuration

```powershell
# PesterConfiguration.Development.psd1
@{
    Run = @{
        Path     = @('./Tests/Unit')
        PassThru = $true
    }

    Output = @{
        Verbosity = 'Detailed'
    }

    CodeCoverage = @{
        Enabled               = $true
        CoveragePercentTarget = 70  # Lower target for development
    }
}
```

### CI/CD Configuration

```powershell
# PesterConfiguration.CI.psd1
@{
    Run = @{
        Path     = @('./Tests/Unit', './Tests/Integration', './Tests/Security')
        PassThru = $true
        Throw    = $true
        Exit     = $true
    }

    Output = @{
        Verbosity  = 'Normal'
        CIFormat   = 'GithubActions'  # or 'AzureDevops'
        RenderMode = 'Ansi'
    }

    CodeCoverage = @{
        Enabled               = $true
        CoveragePercentTarget = 80
        OutputFormat          = 'JaCoCo'
        OutputPath            = './Tests/Results/Coverage.xml'
    }

    TestResult = @{
        Enabled      = $true
        OutputFormat = 'NUnitXml'
        OutputPath   = './Tests/Results/TestResults.xml'
    }
}
```

### Performance Testing Configuration

```powershell
# PesterConfiguration.Performance.psd1
@{
    Run = @{
        Path     = @('./Tests/Performance')
        PassThru = $true

        # Performance tests must not share the box with other work
        Parallel = $false
    }

    Output = @{
        Verbosity = 'Minimal'
    }

    Filter = @{
        Tag = @('Performance', 'Benchmark')
    }

    TestResult = @{
        Enabled    = $true
        OutputPath = './Tests/Results/PerformanceResults.xml'
    }
}
```

## Parallel Execution (Experimental)

Pester 6 can run test **files** concurrently, one file per runspace, using PowerShell 7+
`ForEach-Object -Parallel`.

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests/Unit'
$config.Run.Parallel = $true
$config.Run.ParallelThrottleLimit = 4   # 0 (default) uses all processors
Invoke-Pester -Configuration $config
```

**Requirements**: PowerShell 7+ and file-based containers (`Run.Path`, or `New-PesterContainer
-Path` including parametrized files built with `-Data`).

**Falls back to a sequential run with a warning** when:

- Running on Windows PowerShell 5.1
- Using in-memory `ScriptBlock` containers
- `Run.SkipRemainingOnFailure = 'Run'`

If every file opts out with `#pester:no-parallel` the run is simply sequential, with no warning -
there is nothing left to parallelize.

**Code coverage works under parallel** as of 6.1: each worker measures the same locations and the
parent merges the per-location hits into one report. The cost is that coverage in a parallel run is
forced onto **breakpoint mode**, because the profiler-based tracer keeps its state in a
process-global static and is not concurrency-safe. `CodeCoverage.UseBreakpoints = $false` is ignored
for the parallel path. Breakpoint coverage is substantially slower per file, so parallel plus
coverage is not automatically faster than sequential plus the profiler - measure before adopting it.

**Opting a file out** with a comment directive parsed like `#requires` (matched only inside real
comment tokens, never inside strings):

```powershell
#pester:no-parallel
Describe 'integration that must not share the box' {
}
```

Opted-out files run in the parent session on the normal serial path, with shared session state and
live output, while other files run in parallel.

Console output, the `TestResult` report, and IDE adapters behave the same in both modes - only the
concurrency differs. The run's total `Duration` becomes the orchestrator's elapsed time rather than
the sum of the files, and per-phase run totals (user, framework, discovery) are blank - that
breakdown is still reported on each container.

Treat this as opt-in and experimental. The directive name, config shape, and behavior may still
change.

### Shared Per-File Setup

Pester dot-sources a **`Pester.BeforeContainer.ps1`** from the repository root before **every** test
file is discovered and run, in both serial and parallel runs. This matters most under parallel,
where each worker starts from a clean runspace:

```powershell
# Pester.BeforeContainer.ps1, at the repository root
Import-Module "$PSScriptRoot/Tests/TestHelpers/Assertions.psd1" -Force
. "$PSScriptRoot/Tests/TestHelpers/Bootstrap.ps1"
```

Because it is a real file it always exposes a stable `$PSScriptRoot` and `$PSCommandPath`, so
relative paths have something reliable to anchor against.

> **Removed in 6.1**: the `Run.BeforeContainer` configuration option. 6.0 shipped both the option
> and the convention file; the option had no file to anchor relative paths against, so it was
> dropped and the convention file kept. Assigning `$config.Run.BeforeContainer` now throws
> `The property 'BeforeContainer' cannot be found on this object`. Move the scriptblock's body into
> `Pester.BeforeContainer.ps1` at the repository root.

### Run.RepoRoot Decides Whether It Fires

The convention file is only looked for at `Run.RepoRoot`, and that default is easy to get wrong:

```powershell
$config.Run.RepoRoot = $PSScriptRoot    # be explicit in any script or CI job
```

`Run.RepoRoot` defaults to the nearest ancestor directory containing `.git`, searched upward from
**`[System.IO.Directory]::GetCurrentDirectory()`** - the .NET process working directory - falling
back to that directory when no `.git` is found. It is resolved once, when `New-PesterConfiguration`
is called.

That is _not_ PowerShell's `$PWD`, and `Set-Location` does not update it:

```powershell
Set-Location $repo
(New-PesterConfiguration).Run.RepoRoot.Value   # still the directory the process started in
```

Nor is it derived from `Run.Path`, so pointing Pester at a test directory in another repository does
not move it. When the two diverge the bootstrap silently does not run, and every test that depended
on it fails with `CommandNotFoundException` rather than anything naming the real cause. Set
`Run.RepoRoot` explicitly whenever the run does not start from the repository root.

This does **not** replace per-file setup. Each file must still be able to be discovered on its own;
see [Pester 6 Migration Guide](./v6-migration.md).

## Shuffled Test Order (Experimental)

New in 6.1. `Run.Shuffle` reorders the test files, and the blocks and tests inside them, so a suite
that quietly depends on declaration order fails instead of passing by luck.

```powershell
$config = New-PesterConfiguration
$config.Run.Path    = './Tests/Unit'
$config.Run.Shuffle = $true
Invoke-Pester -Configuration $config
```

Items are reordered only **within their own level** - a test never leaves its `Context`, and a
`Context` never leaves its `Describe`. The tree keeps its shape; only sibling order changes.

The run picks a seed, prints it at the start, and records it on the result object:

```text
Shuffling execution order using seed 852659930. Set 'Run.ShuffleSeed = 852659930' to repeat this order.
```

```powershell
$config.Run.ShuffleSeed = 852659930     # replay the exact order that failed
```

```powershell
# after a PassThru run, the seed that was actually used
$result.Configuration.Run.ShuffleSeed.Value
```

`ShuffleSeed` defaults to `0`, which means "pick a new one each run". Capture the printed seed from
a failing CI log before re-running, or the order is gone.

A file whose blocks genuinely must run in sequence opts out with a comment directive, parsed like
`#requires` and like `#pester:no-parallel`:

```powershell
#pester:no-shuffle
Describe 'ordered migration steps' -Tag 'Integration' {
}
```

Opting out is an admission of order dependence, so treat a `#pester:no-shuffle` file the same way as
a `#pester:no-parallel` one - fine for a genuinely sequential integration script, a smell in a unit
test file.

The option is experimental and may change. Enabling it changes only ordering, never which tests run
or how they are filtered.

## Global Mocks (Experimental)

New in 6.1. Normally a mock applies to calls from the scope that defined it, or from the single
module named by `-ModuleName`. `Mock.Global` makes every mock apply to calls of that command from
**any module or script in the runspace**:

```powershell
$config = New-PesterConfiguration
$config.Mock.Global = $true
```

Mocks are written exactly as before - see
[Mocking Patterns Guide](./mocking-patterns.md#global-mocks-experimental) for what changes in
practice. With the option on, `-ModuleName` becomes a hint used to resolve the command rather than a
scope, so existing mocks keep working. Mocks are still removed when the block that defined them
ends, and are tied to the run that created them, so they cannot leak into a nested Pester-in-Pester
run.

The option is experimental and may change; the Pester team has stated an intent to make it the
default in v7.

## Dynamic Configuration Loading

### Configuration Loader Function

```powershell
function Get-PesterConfiguration {
    [CmdletBinding()]
    param(
        [ValidateSet('Development', 'CI', 'Performance', 'Security', 'Integration')]
        [string]$Environment = 'Development',
        [string]$ConfigPath = './Tests'
    )

    # Load base configuration
    $baseConfigPath = Join-Path $ConfigPath "PesterConfiguration.psd1"
    $baseConfig = Import-PowerShellDataFile $baseConfigPath

    # Load environment-specific overrides
    $envConfigPath = Join-Path $ConfigPath "PesterConfiguration.$Environment.psd1"
    if (Test-Path $envConfigPath) {
        $envConfig = Import-PowerShellDataFile $envConfigPath

        # Merge configurations (environment overrides base)
        $mergedConfig = Merge-HashTable $baseConfig $envConfig
    } else {
        $mergedConfig = $baseConfig
    }

    # Create Pester configuration object
    return New-PesterConfiguration -Hashtable $mergedConfig
}

function Merge-HashTable {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $result = $Base.Clone()

    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-HashTable $result[$key] $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}
```

`New-PesterConfiguration -Hashtable` ignores unknown keys silently. Validate what you loaded:

```powershell
$config = New-PesterConfiguration -Hashtable $mergedConfig
if ($config.CodeCoverage.CoveragePercentTarget.Value -ne $mergedConfig.CodeCoverage.CoveragePercentTarget) {
    throw 'Coverage target did not bind - check the setting name'
}
```

## Test Filtering Configuration

### Tag-Based Filtering

```powershell
# Filter by test type
$config.Filter.Tag = @('Unit')           # Only unit tests
$config.Filter.Tag = @('Integration')    # Only integration tests
$config.Filter.Tag = @('Security')       # Only security tests

# Filter by priority
$config.Filter.Tag = @('Critical')       # Only critical tests
$config.Filter.ExcludeTag = @('Slow')    # Exclude slow tests

# Combined filtering
$config.Filter.Tag = @('Unit', 'Public') # Unit tests for public functions only
```

### The Reserved `None` Tag Value

Pester 6 reserves `None` (case-insensitive) as a filter value meaning **tests that have no tag** on
themselves or any parent block:

```powershell
$config.Filter.Tag = @('None')            # only untagged tests - use to audit tagging coverage
$config.Filter.ExcludeTag = @('None')     # skip untagged tests, run only tagged ones
$config.Filter.Tag = @('None', 'Acceptance')  # untagged tests plus Acceptance
```

Never use `None` as a literal tag name. If an existing suite does, rename it - filtering by it now
also selects every untagged test.

### Path-Based Filtering

```powershell
# Test specific modules
$config.Run.Path = @('./Tests/Unit/Public/Get-*.Tests.ps1')

# Test specific areas
$config.Run.Path = @('./Tests/Unit/Authentication', './Tests/Unit/Authorization')
```

### Excluding Paths

Pester 6 discovers test files inside **hidden and dot-prefixed folders** (file search uses
`Get-ChildItem -Force`). Version-control metadata folders (`.git`, `.svn`, `.hg`) are still ignored.
Exclude anything else you do not want picked up:

```powershell
$config.Run.ExcludePath = @(
    './.build/**',
    './.config/**',
    './Tests/Fixtures/**'
)
```

## Code Coverage Configuration

### Coverage Paths

```powershell
$config.CodeCoverage.Path = @(
    './Public/*.ps1',           # All public functions
    './Private/*.ps1',          # All private functions
    './Classes/*.ps1',          # All class files
    './Modules/*/Public/*.ps1'  # Multi-module support
)
```

There is no `CodeCoverage.ExcludePath`. Narrow `CodeCoverage.Path` instead, and rely on
`CodeCoverage.ExcludeTests = $true` (the default) to keep `*.Tests.ps1` files out of the numbers.

### Profiler vs. Breakpoint Coverage

Pester 6 uses the Profiler's tracer by default instead of setting a breakpoint on every command.
This is dramatically faster on large code bases. The old behavior is still available:

```powershell
$config.CodeCoverage.UseBreakpoints = $true   # only if you depend on breakpoint-based numbers
```

A parallel run overrides this and always uses breakpoints - see
[Parallel Execution](#parallel-execution-experimental) above.

### Output Formats and Report Root

```powershell
$config.CodeCoverage.OutputFormat = 'JaCoCo'      # default
$config.CodeCoverage.OutputFormat = 'Cobertura'   # for GitLab, Codecov, and similar
```

`CoverageGutters` was **removed** in v6. It only existed to produce repo-root-relative paths, and
now _all_ coverage output is relative to the repository root, so plain `JaCoCo` works with the
Coverage Gutters extension.

Paths are relative to `CodeCoverage.ReportRoot`, which defaults to `Run.RepoRoot` (found from the
nearest `.git` directory, falling back to the working directory). Override it when the repo layout
does not match what your CI tool expects:

```powershell
$config.CodeCoverage.ReportRoot = "$PSScriptRoot/.."
```

## Output Configuration

### Verbosity Levels

```powershell
$config.Output.Verbosity = 'None'        # No output
$config.Output.Verbosity = 'Minimal'     # Only summary
$config.Output.Verbosity = 'Normal'      # Standard output (default)
$config.Output.Verbosity = 'Detailed'    # Verbose output with test details
$config.Output.Verbosity = 'Diagnostic'  # Full diagnostic information
```

### Render Mode

```powershell
$config.Output.RenderMode = 'Auto'          # detect terminal capability (default)
$config.Output.RenderMode = 'Ansi'          # force ANSI/VT sequences
$config.Output.RenderMode = 'ConsoleColor'  # legacy console colors
$config.Output.RenderMode = 'Plaintext'     # no color - best for log capture
```

### CI/CD Integration

```powershell
$config.Output.CIFormat = 'GithubActions'  # GitHub Actions error/warning annotations
$config.Output.CIFormat = 'AzureDevops'    # Azure DevOps logging commands
$config.Output.CIFormat = 'Auto'           # Auto-detect (default)
$config.Output.CILogLevel = 'Error'        # Error | Warning
$config.Output.CIDebugOutput = 'Auto'      # Auto | None
```

`CIDebugOutput = 'Auto'` (the default) surfaces `Write-Verbose` and `Write-Debug` output when the CI
system is running with its own debug switch on - Azure DevOps `System.Debug`, GitHub Actions runner
debug logging. Set it to `None` to keep a re-run-with-debug quiet.

### Showing Tags

```powershell
$config.Output.ShowTags = $true
# Describing Get-Planet [Tags: Slow, Unix]
```

Appends each `Describe`, `Context`, and `It` tag list to its output line. Use it when a `-Tag` or
`-ExcludeTag` filter selects a surprising set of tests - it shows what the filter actually matched
rather than leaving you to infer it from the names.

### Stack Traces

```powershell
$config.Output.StackTraceVerbosity = 'None'
$config.Output.StackTraceVerbosity = 'FirstLine'
$config.Output.StackTraceVerbosity = 'Filtered'  # default - hides Pester internals
$config.Output.StackTraceVerbosity = 'Full'
```

## Test Result Configuration

### Output Formats

```powershell
$config.TestResult.OutputFormat = 'NUnitXml'   # NUnit 2.5 schema, most widely consumed (default)
$config.TestResult.OutputFormat = 'NUnit2.5'   # explicit alias for the above
$config.TestResult.OutputFormat = 'NUnit3'     # NUnit 3 schema, new in v6
$config.TestResult.OutputFormat = 'JUnitXml'   # JUnit, for GitLab and most Java-ecosystem tools
```

Reports honor `TestResult.OutputEncoding`. Control characters and ANSI/VT sequences in values are
escaped using Unicode Control Pictures so they cannot corrupt the report XML.

### Multiple Output Formats

`TestResult` is a single section, not a collection - you cannot configure two formats in one run.
Convert the result object afterwards instead:

```powershell
$config.Run.PassThru = $true
$result = Invoke-Pester -Configuration $config

Export-NUnitReport -Result $result -Path './Tests/Results/NUnit.xml'
Export-JUnitReport -Result $result -Path './Tests/Results/JUnit.xml'
```

## Configuration Best Practices

### Environment Detection

```powershell
# Auto-detect CI/CD environment
if ($env:CI -eq 'true' -or $env:BUILD_ID) {
    $environment = 'CI'
} elseif ($env:PERFORMANCE_TESTING -eq 'true') {
    $environment = 'Performance'
} else {
    $environment = 'Development'
}

$config = Get-PesterConfiguration -Environment $environment
```

### Configuration Validation

```powershell
function Test-PesterConfiguration {
    param([PesterConfiguration]$Configuration)

    # Validate Pester version
    $pester = Get-Module Pester -ListAvailable |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($pester.Version -lt [version]'6.1.0') {
        throw "Pester 6.1+ required, found $($pester.Version)"
    }

    # Validate required paths exist
    foreach ($path in $Configuration.Run.Path.Value) {
        if (-not (Test-Path $path)) {
            Write-Warning "Test path not found: $path"
        }
    }

    # Validate output directories
    $outputDir = Split-Path $Configuration.TestResult.OutputPath.Value -Parent
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    # Validate coverage target
    $target = $Configuration.CodeCoverage.CoveragePercentTarget.Value
    if ($target -gt 100 -or $target -lt 0) {
        throw "Invalid coverage target: $target"
    }

    # Parallel is silently ignored on 5.1 - warn rather than let it look enabled
    if ($Configuration.Run.Parallel.Value -and $PSVersionTable.PSVersion.Major -lt 7) {
        Write-Warning 'Run.Parallel requires PowerShell 7+; the run will fall back to sequential'
    }
}
```

Note that reading a value off the configuration object gives you an option wrapper - use `.Value`
to get the underlying setting.

### Configuration Inheritance

```powershell
# Base configuration for organization
$orgConfig = @{
    CodeCoverage = @{
        CoveragePercentTarget = 80
        OutputFormat          = 'JaCoCo'
    }
    TestResult = @{
        OutputFormat = 'NUnitXml'
    }
}

# Project-specific overrides
$projectConfig = @{
    CodeCoverage = @{
        CoveragePercentTarget = 85  # Higher target for critical project
    }
}

# Merge configurations
$finalConfig = Merge-HashTable $orgConfig $projectConfig
```
