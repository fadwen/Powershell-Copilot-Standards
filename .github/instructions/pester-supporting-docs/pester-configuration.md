# Pester Configuration Guide

Targets **Pester 6.0+**. All settings below were verified against the `PesterConfiguration` object.

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
    }

    Output = @{
        Verbosity           = 'Detailed'
        StackTraceVerbosity = 'Filtered'   # None | FirstLine | Filtered | Full
        CIFormat            = 'Auto'       # Auto | AzureDevops | GithubActions
        CILogLevel          = 'Error'
        RenderMode          = 'Auto'       # Auto | Ansi | ConsoleColor | Plaintext
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
- `CodeCoverage` is enabled (coverage is always collected sequentially)
- `Run.SkipRemainingOnFailure = 'Run'`
- Every file opts out with `#pester:no-parallel`

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

`Run.BeforeContainer` takes scriptblocks that run before **every** test file is discovered and run,
in both serial and parallel runs. This matters most under parallel, where each worker starts from a
clean runspace:

```powershell
$config.Run.BeforeContainer = { . './setup.ps1' }
```

If unset, Pester dot-sources a `Pester.BeforeContainer.ps1` from the repository root
(`Run.RepoRoot`, found from the nearest `.git` directory) when one is present - a zero-config
per-repo bootstrap. Setting `Run.BeforeContainer` overrides the convention file.

This does **not** replace per-file setup. Each file must still be able to be discovered on its own;
see [Pester 6 Migration Guide](./v6-migration.md).

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

Note that breakpoint-based coverage forces a sequential run when `Run.Parallel` is set.

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
```

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
    if ($pester.Version -lt [version]'6.0.0') {
        throw "Pester 6.0+ required, found $($pester.Version)"
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
