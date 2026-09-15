# Pester Test Structure Guide

Targets **Pester 6.2+**.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Standard Test Directory Organization

Create organized test directory structure for enterprise PowerShell projects:

```text
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
│   │   └── CompleteWorkflow.Tests.ps1
│   └── SystemIntegration/
│       └── ExternalServices.Tests.ps1
├── Performance/
│   ├── Benchmarks/
│   │   └── ExecutionTime.Tests.ps1
│   └── LoadTests/
│       └── MemoryUsage.Tests.ps1
├── Security/
│   ├── InputValidation/
│   │   └── ParameterSanitization.Tests.ps1
│   └── CredentialHandling/
│       └── SecureCredentials.Tests.ps1
├── TestData/
│   ├── sample-data.json
│   ├── test-config.psd1
│   └── mock-responses.json
├── TestHelpers/
│   ├── TestHelpers.ps1
│   ├── MockFactory.ps1
│   └── TestDataGenerator.ps1
├── Results/
│   ├── Coverage.xml
│   └── TestResults.xml
├── Pester.BeforeContainer.ps1   <- optional, applies to Tests/ and below (6.2+)
├── PesterConfiguration.psd1
└── Invoke-Tests.ps1

Pester.BeforeContainer.ps1     <- optional, at REPOSITORY ROOT - applies to every test file
```

`Pester.BeforeContainer.ps1` is looked for at the repository root - the directory containing `.git`,
which Pester exposes as `Run.RepoRoot` - and, from 6.2, in every folder between there and the test
file. When present, Pester dot-sources each one before **every** test file below it is discovered
and run, outermost first, in both serial and parallel runs. As of 6.1 this is the only
shared-bootstrap mechanism; the `Run.BeforeContainer` option was removed.

## Test File Isolation (Pester 6)

Pester 6 discovers and runs **one file at a time**, interleaving discovery and execution, rather
than discovering every file up front. Under `Run.Parallel` each file is discovered in its own
runspace.

**Every test file must be self-contained.** It must import the modules it needs and perform its own
discovery-time setup. It cannot rely on a file that happened to be discovered earlier.

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }

BeforeDiscovery {
    # Only what is needed to BUILD the test tree: -ForEach data, helper commands
    Import-Module "$PSScriptRoot/../../../ModuleName.psd1" -Force
    $script:PublicCommands = (Get-Module ModuleName).ExportedFunctions.Keys
}

BeforeAll {
    # What is needed to RUN the tests
    Import-Module "$PSScriptRoot/../../../ModuleName.psd1" -Force
    . "$PSScriptRoot/../../TestHelpers/TestHelpers.ps1"
}
```

This was always the recommended style. In Pester 6 it is the model, so suites that were already
isolated need no changes.

### Shared Bootstrap

When many files need identical setup, put it in one place rather than duplicating it. The setup file
follows the same rule as a test file: top-level code runs during **discovery** only, and what the
tests need at **run** time goes in a `BeforeAll`:

```powershell
# Pester.BeforeContainer.ps1 at the repository root

# Discovery only - keep this only where a -ForEach or BeforeDiscovery needs it
Import-Module "$PSScriptRoot/Source/ModuleName.psd1" -Force

# Run time - what the tests themselves need
BeforeAll {
    Import-Module "$PSScriptRoot/Source/ModuleName.psd1" -Force
    . "$PSScriptRoot/Tests/TestHelpers/TestHelpers.ps1"
}
```

Before 6.2 everything sat at top level and reached the tests. On 6.2 that shape fails silently: a
function or variable dot-sourced at top level is gone by the time a test runs (the helper call fails
with `CommandNotFoundException`, the variable reads as `$null`), and only `Import-Module` happens to
survive because module state is session-wide. Wrap run-time setup in `BeforeAll`, and keep the
top-level part only where discovery genuinely needs it.

Anchor every path in it to `$PSScriptRoot`. The file runs before each container in both serial and
parallel runs, and a relative path would resolve against whatever the working directory happens to
be - which is precisely why the `Run.BeforeContainer` scriptblock option was removed in 6.1. It runs
once per container, so what it does must be safe to repeat.

#### Per-folder setup (6.2+)

A `Pester.BeforeContainer.ps1` in a subfolder applies to that folder and below, after the ones
above it, so each suite carries only what it needs:

```powershell
# Tests/Unit/Pester.BeforeContainer.ps1
BeforeAll { $script:Db = 'in-memory' }

# Tests/Integration/Pester.BeforeContainer.ps1
BeforeAll { $script:Db = 'real-sql' }
```

Each file is dot-sourced into the container's own scope, so `Tests/Integration` never inherits what
`Tests/Unit` set up, whichever runs first. A folder that wants none of the setup above it starts its
file with `#pester:no-inherit`. The result object records which files applied to each container as
`BeforeContainerFile`, outermost first - see
[Pester Configuration Guide](./pester-configuration.md#folder-scoped-setup-62).

If the bootstrap does not appear to run, check `Run.RepoRoot` - the chain starts there. From 6.2 the
run resolves it from the session's current location when it is unset (6.1 used the .NET process
working directory), so a run launched from outside the repository, or against a checkout with no
`.git` folder, still looks in the wrong place and simply finds nothing:

```powershell
$config.Run.RepoRoot = $PSScriptRoot
```

This supplements per-file setup; it does not remove the requirement that a file be independently
discoverable.

## File Naming Conventions

### Test Files

- **Unit Tests**: `FunctionName.Tests.ps1`
- **Integration Tests**: `ComponentName.Tests.ps1`
- **Performance Tests**: `PerformanceArea.Tests.ps1`
- **Security Tests**: `SecurityArea.Tests.ps1`

The `.Tests.ps1` suffix is configurable via `Run.TestExtension` but should not be changed.

### Test Organization

- **Public Functions**: One test file per public function
- **Private Functions**: Group related private functions in single test file
- **Classes**: One test file per class
- **Integration**: Group by business workflow or system integration

### Hidden Folders Are Now Discovered

Pester 6 searches with `Get-ChildItem -Force`, so `*.Tests.ps1` files in hidden or dot-prefixed
folders (for example `.build` or `.config`) **are** discovered and run. Previously they were
skipped. Version-control metadata folders (`.git`, `.svn`, `.hg`) are still ignored.

Exclude anything else you do not want picked up:

```powershell
$config.Run.ExcludePath = @('./.build/**', './Tests/Fixtures/**')
```

## Test Tags Strategy

Use consistent tagging for test categorization:

```powershell
Describe "Function-Name" -Tag "Unit", "Public" {
    # Unit tests for public functions
}

Describe "Integration-Workflow" -Tag "Integration", "EndToEnd" {
    # Integration tests
}

Describe "Performance-Baseline" -Tag "Performance", "Benchmark" {
    # Performance tests
}

Describe "Security-Validation" -Tag "Security", "InputValidation" {
    # Security tests
}
```

### `None` Is a Reserved Tag Value

In Pester 6, `None` (case-insensitive) is a reserved **filter** value meaning "tests that have no tag
on themselves or any parent block". Never use it as a literal tag name.

Use it to audit tagging coverage - a well-tagged suite **runs** zero tests:

```powershell
Invoke-Pester -Path ./Tests -TagFilter 'None'          # find untagged tests
Invoke-Pester -Path ./Tests -ExcludeTagFilter 'None'   # run only tagged tests
Invoke-Pester -Path ./Tests -TagFilter None, Acceptance
```

Reading that interactively, look at the **Passed** count in the summary rather than the discovered
count, which stays at the full suite size.

Add the audit to CI so untagged tests cannot slip in. Count `ShouldRun`, the flag the filter
actually sets:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Filter.Tag = 'None'
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
$config.Output.Verbosity = 'None'

$result = Invoke-Pester -Configuration $config

$untagged = @($result.Tests | Where-Object ShouldRun)
if ($untagged.Count -gt 0) {
    $untagged | ForEach-Object { Write-Host "::error::Untagged test: $($_.ExpandedPath)" }
    throw "$($untagged.Count) test(s) have no tag. Tag every Describe block."
}
```

**Do not gate on `TotalCount` or `PassedCount`.** Both are wrong here, in opposite directions:

| Signal | Behaviour under `Filter.Tag = 'None'` |
| --- | --- |
| `TotalCount` | Ignores the filter and counts everything **discovered**, so it is non-zero for any non-empty suite. A gate on it can never pass |
| `PassedCount` | Counts only untagged tests that ran **and passed**, so an untagged test that fails is missed. With `Run.SkipRun` nothing runs, so it is always `0` |
| `ShouldRun` | Set by the filter on exactly the matching tests. Correct with or without `SkipRun`, and it names them |

Verified against Pester 6.1.0: on one tagged plus one untagged test, `TotalCount` is `2` and
`ShouldRun` is `1`; on a fully tagged suite, `TotalCount` is `2` and `ShouldRun` is `0`.

### Opting Files Out of Parallel Execution

Tests that must not share the machine - performance benchmarks, tests binding a fixed port, tests
mutating global state - opt out with a comment directive parsed like `#requires`:

```powershell
#pester:no-parallel
Describe "Performance-Baseline" -Tag "Performance", "Benchmark" {
}
```

These files run in the parent session on the normal serial path while other files run in parallel.
Put the directive at the top of the file; it is matched only inside real comment tokens, never
inside strings.

## Quality Organization Standards

### Test File Requirements

- Each test file must import its own modules in `BeforeAll` (and `BeforeDiscovery` when discovery
  needs them)
- All external dependencies must be mocked appropriately
- Test isolation must be maintained between tests **and between files**
- Clean test data and resources in `AfterAll` or `AfterEach`
- Every `Describe` block carries at least one tag
- No `-ForEach` / `-TestCases` expression can evaluate to `$null` or `@()`

### Verifying Structure

A discovery-only pass validates the whole suite's structure without paying for a full run. It
surfaces empty `-ForEach` sets, files that cannot be discovered independently, and - from 6.2 - a
configuration value of the wrong type:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
Invoke-Pester -Configuration $config
```

Run this in CI before the real test job. It is fast and catches structural breakage early.

### Documentation Integration

- Reference troubleshooting guides in `./Troubleshooting/` folder
- Include performance baselines and expectations
- Document test data requirements and setup
- Maintain test execution guidelines in main test runner
