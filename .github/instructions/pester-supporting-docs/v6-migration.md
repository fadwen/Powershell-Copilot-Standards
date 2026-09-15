# Pester 6 Migration Guide

Pester 6.0.0 shipped 2026-07-07. It builds on the v5 runtime (Discovery and Run, the configuration
object, the rich result object). The test-authoring API and configuration object are unchanged, so
most suites upgrade with small, mechanical edits.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Supported Platforms

Pester 6 targets **Windows PowerShell 5.1** and **PowerShell 7.4+**. Support for PowerShell 3, 4, 6,
and unsupported 7.x was removed. Update CI matrices accordingly - `7.2` and `7.3` entries no longer
apply.

```powershell
#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
```

These standards target **6.2+**. Nothing in 6.1 or 6.2 breaks a test file written for 6.0, so the
migration below is the whole job for test files; see [Moving From 6.0 to 6.1](#moving-from-60-to-61)
and [Moving From 6.1 to 6.2](#moving-from-61-to-62) at the end for what changed underneath -
configuration, positional parameters, and the shape of `Pester.BeforeContainer.ps1`.

## Upgrade Checklist

Work through these in order. Items 1-3 are hard breakages that fail immediately; the rest are
behavior changes that can pass silently and mislead.

- [ ] **1. Replace `Assert-MockCalled` and `Assert-VerifiableMock`.** Both were **removed**. Use
      `Should -Invoke` / `Should -InvokeVerifiable`, or the new `Should-Invoke` / `Should-NotInvoke`.
- [ ] **2. Remove `-Focus` and `-Pending`.** `Describe`/`Context`/`It` no longer accept `-Focus`, and
      the `Focus` property is gone from the result object. `Set-ItResult -Pending` is gone - use
      `-Skipped` or `-Inconclusive`. Use `-Skip`, tags, or `Filter` to select which tests run.
- [ ] **3. Audit every `-ForEach` / `-TestCases` that can produce an empty set.** `$null` or `@()`
      now **fails discovery** (`Run.FailOnNullOrEmptyForEach`, on by default). Opt out per block or
      test with `-AllowNullOrEmptyForEach`, or fix the generator so it cannot be empty.
- [ ] **4. Make every test file self-contained.** Discovery and run now happen per file - a module
      imported at discovery time in one file is not guaranteed to be loaded when another file is
      discovered. See below.
- [ ] **5. Check for a literal tag named `None`.** `None` is now a reserved filter value meaning
      "tests with no tags". Rename any real tag called `None`.
- [ ] **6. Review code coverage settings.** Profiler-based coverage is now the default; set
      `CodeCoverage.UseBreakpoints = $true` only if you depend on breakpoint-based numbers. The
      `CoverageGutters` output format was **removed** - use `JaCoCo` or `Cobertura`.
- [ ] **7. Check test and block names containing `<...>`.** Only `<...>` templates are expanded now,
      and their contents are evaluated as full PowerShell expressions.
- [ ] **8. Check for `*.Tests.ps1` in hidden or dot-prefixed folders.** These are now discovered and
      run. Add `Run.ExcludePath` entries for any you do not want picked up.
- [ ] **9. Adopt `Should-*` assertions in new tests.** Optional and additive - see
      [Assertion Guide](./assertion-guide.md). Do not set `Should.DisableV5 = $true` until the whole
      suite is migrated.

A second `BeforeAll` (or `BeforeEach`, `AfterAll`, `AfterEach`) in one block threw in 6.0 and 6.1
and was a migration item. 6.2 allows it again - see
[Moving From 6.1 to 6.2](#moving-from-61-to-62) - so it is no longer on the list.

## Discovery and Run Now Happen Per File

This is the most significant change, and it is invisible for well-isolated suites.

In v5 a run had two global phases: Pester discovered **every** file first, building the whole tree
of `Describe`/`Context`/`It` blocks, and only then ran them all. In v6 the unit of work is a single
file: Pester discovers a file and runs it before moving to the next, interleaving discovery and
execution. This is what makes parallel execution possible, and serial runs follow the same model so
the two behave consistently.

**What this breaks.** Discovery-time side effects no longer carry across files:

- A module imported at discovery time in one file (at the top of the file, or inside
  `BeforeDiscovery`) is not guaranteed to be loaded while another file is being discovered. Under
  `Run.Parallel` it definitely is not - each file is discovered in its own runspace.
- Anything a file needs in order to be _discovered_ - helper modules, the data behind a `-ForEach`
  or `BeforeDiscovery`, variables - must be set up **by that file**.

```powershell
# WRONG - relies on another file having imported the module during discovery
BeforeDiscovery {
    $script:Cases = Get-ModuleTestCase   # command may not exist yet
}

# RIGHT - the file sets up its own discovery-time dependencies
BeforeDiscovery {
    Import-Module "$PSScriptRoot/../../MyModule.psd1" -Force
    $script:Cases = Get-ModuleTestCase
}
```

Runtime setup in `BeforeAll` was never affected by this and still works as before.

**Shared bootstrap.** When several files need the same setup, put a `Pester.BeforeContainer.ps1` in
the repository root (`Run.RepoRoot`). Pester dot-sources it before **every** test file is discovered
and run, in both serial and parallel runs. Run-time setup goes in a `BeforeAll`; the file's top-level
code runs at discovery only (6.2):

```powershell
# Pester.BeforeContainer.ps1, at the repository root
BeforeAll {
    . "$PSScriptRoot/Tests/TestHelpers/Bootstrap.ps1"
}
```

6.0 also offered a `Run.BeforeContainer` configuration option for this. It was **removed in 6.1** -
see [Moving From 6.0 to 6.1](#moving-from-60-to-61). The convention file is now the only mechanism,
and from 6.2 it may also sit in any folder under the root - see
[Moving From 6.1 to 6.2](#moving-from-61-to-62).

**Console output changed.** A run prints one `Running tests from N files.` banner, then per-file
results, then one grand-total summary. The old `Starting discovery in N files.` /
`Discovery found X tests` / `Running tests.` framing is no longer printed during a normal run. A
discovery-only run (`Run.SkipRun = $true`) still prints discovery counts. Do not parse for the old
strings.

## Test and Block Name Expansion

In v5 names were expanded by re-parsing the whole name as a double-quoted string. A literal
backtick, `$`, `$(...)` or quote could break the name or be used to run code. In v6 **only `<...>`
tokens become sub-expressions; every other character stays inert.**

Inside `<...>` the content is now evaluated as a full PowerShell expression - the current
`-ForEach`/`-TestCases` item and its properties, any in-scope variable, arithmetic, method calls -
and the result is rendered through Pester's formatter. This is broader than v5, which substituted
only simple data/variable/property references and left anything more complex verbatim.

```powershell
It 'adds up to <($a + $b)>'    # v5: literal text.  v6: renders "adds up to 3"
It 'has `<literal brackets>'   # escape the leading bracket to keep the literal text
It 'handles `backticks`'       # v5: parse error.   v6: fine, stays literal
```

Arrays, hashtables, and objects interpolated via `<...>` now render through Pester's formatter, so
they read properly in the test name instead of printing as `System.Object[]`.

## Configuration Changes

| Setting | Change |
| --- | --- |
| `Run.Parallel` | New. Experimental parallel runner, one file per runspace |
| `Run.ParallelThrottleLimit` | New. Cap concurrent files; `0` (default) uses all processors |
| `Run.BeforeContainer` | New in 6.0, **removed in 6.1**. Use a `Pester.BeforeContainer.ps1` at the repo root |
| `Run.RepoRoot` | New. Repository root, found from the `.git` directory |
| `Run.FailOnNullOrEmptyForEach` | New, default `$true`. Empty `-ForEach` fails discovery |
| `Run.SkipRemainingOnFailure` | `None`, `Run`, `Container`, `Block` |
| `Should.DisableV5` | New. `$true` makes `Should -Be` throw |
| `CodeCoverage.UseBreakpoints` | Default flipped to `$false` (profiler-based, much faster) |
| `CodeCoverage.OutputFormat` | `CoverageGutters` **removed**. Use `JaCoCo` or `Cobertura` |
| `CodeCoverage.ExcludeTests` | Default `$true`. Keeps test files out of coverage numbers |
| `CodeCoverage.ReportRoot` | New. Defaults to `Run.RepoRoot`; coverage paths are relative to it |
| `TestResult.OutputFormat` | `NUnit3` added. Valid: `NUnitXml`, `NUnit2.5`, `NUnit3`, `JUnitXml` |
| `Output.RenderMode` | New. `Auto`, `Ansi`, `ConsoleColor`, `Plaintext` |
| `Debug.ShowStartMarkers` | New. Writes an indication when each test starts |

`TestResult` and `CodeCoverage` now **auto-enable** when you set any of their non-default options,
so you cannot silently configure a report that never gets written.

There is **no** `CodeCoverage.Threshold` or `CodeCoverage.PerFileThreshold` setting - that was never
real. The coverage target is `CodeCoverage.CoveragePercentTarget` (default `75`).

## Removed and Renamed

| Removed in v6 | Replacement |
| --- | --- |
| `Assert-MockCalled` | `Should -Invoke` or `Should-Invoke` |
| `Assert-VerifiableMock` | `Should -InvokeVerifiable` or `Should-Invoke -Verifiable` |
| `-Focus` on `Describe`/`Context`/`It` | `-Skip`, tags, or `Filter` configuration |
| `Set-ItResult -Pending`, `Pending` status | `Set-ItResult -Skipped` or `-Inconclusive` |
| `CodeCoverage.OutputFormat = 'CoverageGutters'` | `JaCoCo` (works with Coverage Gutters now) |
| Mock fall-through to the real command | Define the behavior explicitly in the mock |
| `Invoke-Pester` Legacy parameter set | `-Configuration` with a `PesterConfiguration` object |

Mock **fall-through to the real command** was removed for predictability. A mock whose
`-ParameterFilter` does not match no longer quietly calls the real command - define every case you
need explicitly.

## Reserved Tag Filter Value: None

`-TagFilter 'None'` / `Filter.Tag = 'None'` now selects **tests that have no tag** on themselves or
any parent block. `-ExcludeTagFilter 'None'` skips untagged tests so you can run only tagged ones.
Combine with real tags: `-TagFilter None, Acceptance`. Comparison is case-insensitive.

This is useful for finding tests that escaped the tagging convention:

```powershell
Invoke-Pester -Path ./Tests -TagFilter 'None'   # a well-tagged suite RUNS zero tests
```

Read the **Passed** count in the summary, not the discovered count. The discovered count stays at
the full suite size - `TotalCount` ignores the filter - so a scripted gate must count
`$result.Tests | Where-Object ShouldRun` instead. `PassedCount` does not work for a gate either: it
misses an untagged test that fails, and it is always `0` under `Run.SkipRun`. See
[Test Execution Guide](./test-execution.md).

If you used `None` as a literal tag, rename it - filtering by it now also selects every untagged
test.

## Parallel Execution (Experimental)

See [Test Execution Guide](./test-execution.md) for the full treatment. In short:

```powershell
$config.Run.Parallel = $true
$config.Run.ParallelThrottleLimit = 4   # 0 (default) uses all processors
```

Requires file-based containers. Runs on PowerShell 7 and, from 6.2, on Windows PowerShell 5.1 (6.0
and 6.1 fell back to sequential there). Falls back to a sequential run **with a warning** for
in-memory `ScriptBlock` containers and when `Run.SkipRemainingOnFailure = 'Run'`. Coverage under
parallel was unsupported in 6.0 and works from 6.1 onward, at the cost of forced breakpoint mode -
see [Test Execution Guide](./test-execution.md).

Opt a single file out with a comment directive parsed like `#requires`:

```powershell
#pester:no-parallel
Describe 'integration that must not share the box' {
}
```

Treat `Run.Parallel` as opt-in. The directive name, config shape, and behavior may still change
before it is declared stable.

## Verifying The Migration

```powershell
# 1. Confirm the installed version
Get-Module Pester -ListAvailable | Select-Object Name, Version

# 2. Find removed mock commands
Get-ChildItem -Recurse -Filter *.Tests.ps1 |
    Select-String -Pattern 'Assert-MockCalled|Assert-VerifiableMock' |
    Select-Object Path, LineNumber, Line

# 3. Find removed test-selection features
Get-ChildItem -Recurse -Filter *.Tests.ps1 |
    Select-String -Pattern '-Focus\b|Set-ItResult\s+-Pending' |
    Select-Object Path, LineNumber, Line

# 4. Discovery-only pass - surfaces empty -ForEach sets and files that cannot be discovered alone
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
Invoke-Pester -Configuration $config

# 5. Find untagged tests
Invoke-Pester -Path ./Tests -TagFilter 'None'
```

Step 4 is the highest-value check: it walks every file through discovery, so empty `-ForEach` sets
and files that depend on another file having run first fail there without paying for a full run.

## Moving From 6.0 to 6.1

6.1.0 is overwhelmingly additive for **test files** - the assertion and mocking APIs a test file uses
did not lose anything. The breakages are in **configuration** and in a few positional parameters.

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }
```

### Removed in 6.1

Neither of these appears in the 6.1.0 release announcement. Check for both before upgrading.

- [ ] **`Run.BeforeContainer` was removed.** 6.0 had two bootstrap mechanisms - this option and the
      `Pester.BeforeContainer.ps1` convention file. The option had no file to anchor relative paths
      against, so it was dropped. Assigning it now throws
      `The property 'BeforeContainer' cannot be found on this object`. Move the scriptblock body
      into a `Pester.BeforeContainer.ps1` at the repository root.

- [ ] **A hashtable config lost it silently on 6.1.** `New-PesterConfiguration -Hashtable` ignored
      unknown keys, so a `Run.BeforeContainer` entry in a `PesterConfiguration.psd1` did **not**
      throw - the bootstrap simply stopped running. From 6.2 `Invoke-Pester` warns
      `Ignoring configuration keys 'Run.BeforeContainer'`; on 6.1 grep for the name rather than
      relying on the run to tell you.

- [ ] **`Should-BeEquivalent -StrictOrder` was removed.** It never worked. If a call passes it,
      the switch was not doing what its name implied - assert collection order with
      `Should-BeCollection` instead.

### Positional Parameters Moved

6.1 made `-Actual` bind consistently across the new assertions: **`Position = 0` on a single-subject
assertion**, `Position = 1` when a positional `-Expected` already sits at `Position = 0`. Named
arguments and piped input are unaffected; only positional `-Actual` calls can break.

`Should-BeHashtable` is the one most likely to bite - its `-Actual` moved from position 1 to 0:

```powershell
Get-Command -Syntax Should-BeHashtable    # confirm against the installed version
```

`-Expected` also became **mandatory** on `Should-NotBeString`, `Should-BeFasterThan`, and
`Should-BeSlowerThan`. A call that omitted it was not asserting anything meaningful, so this
surfaces a latent bug rather than creating one.

`Should-Throw -Because` became **named-only**; a positional third argument no longer binds to it.

### What Is New

| Addition | Where |
| --- | --- |
| `New-ShouldAssertion` - author your own `Should-*` assertions | [Custom Assertion Guide](./custom-assertions.md) |
| `Mock.Global` - a mock reaches every module in the runspace (experimental) | [Mocking Patterns Guide](./mocking-patterns.md#global-mocks-experimental) |
| `Run.Shuffle` / `Run.ShuffleSeed` - randomize order to surface order dependence (experimental) | [Test Execution Guide](./test-execution.md) |
| `Output.ShowTags` - append `[Tags: ...]` to output lines | [Pester Configuration Guide](./pester-configuration.md) |
| `Output.CIDebugOutput` - surface verbose/debug on a CI debug re-run | [Pester Configuration Guide](./pester-configuration.md) |
| `Should-BeString -NormalizeLineEnding` | [Assertion Guide](./assertion-guide.md) |
| `Should-ContainCollection -IgnoreOrder` | [Assertion Guide](./assertion-guide.md) |
| Code coverage collected under `Run.Parallel` | [Test Execution Guide](./test-execution.md) |

### Behavior Worth Knowing About

None of these fail an existing suite, but they change what you see:

- **`Should-Throw -ExceptionMessage` explains wildcard mismatches.** A message containing `[ ] * ?`
  that failed against itself now says why instead of printing two identical-looking strings.
- **Report output paths are resolved to absolute during configuration,** including a relative
  `CodeCoverage.ReportRoot`. A job that wrote its report relative to a directory it changed into
  mid-run now writes where the path pointed when the configuration was built.
- **`Should-BeString -Expected` accepts an empty string,** which previously tripped the mandatory
  check.
- **`ExcludePath` excludes directories,** not only files. An entry that was silently doing nothing
  starts excluding.
- **A stray unmatched-label `break`/`continue` fails its test** instead of aborting the whole run,
  so a suite that appeared to stop early now reports a failure and keeps going - expect the failed
  count to rise and the test count to rise with it.
- **The `Normal`-verbosity passing container line carries a test count.** Anything scraping that
  line needs to tolerate the extra field.
- **Type assertions honor `PSTypeNames`,** so `Should-HaveType 'MyModule.Session'` works against a
  synthetic type name.
- **Skipped data-driven tests expand their names.** `handles <_>` repeated N times becomes
  `handles foo`, `handles bar`. A CI report that keyed off the raw template text will see new
  strings.
- **Complex values are summarised in failure messages.** A `CommandInfo` renders as
  `FunctionInfo{Name=Invoke-Pester}` instead of expanding into a slow, huge tree.
- **Containers that fail during discovery reach the `TestResult` XML** instead of vanishing from it.
  A report consumer counting test cases may see entries it did not see before - which is the point.

### Adopting the Experimental Options

`Mock.Global` and `Run.Shuffle` are both off by default and configured per run:

```powershell
$config = New-PesterConfiguration
$config.Mock.Global = $true
$config.Run.Shuffle = $true
```

Turning either on can surface real problems in an existing suite - that is what they are for.
`Mock.Global` can make a previously-unmocked call start hitting a mock; `Run.Shuffle` fails tests
that depended on declaration order. Both may still change before they are declared stable, so pin
the behavior you rely on in a dedicated job rather than across the whole suite.

## Moving From 6.1 to 6.2

6.2.0 shipped 2026-09-09. It is additive for test files - no assertion or mocking API a test file
uses was removed or renamed. The changes that can affect an existing suite are in
`Pester.BeforeContainer.ps1`, in the two timing assertions, and in how the configuration treats bad
input. Everything below was verified against an installed 6.2.0.

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.2.0' }
```

### Check Before Upgrading

- [ ] **Top-level code in `Pester.BeforeContainer.ps1` runs during discovery only.** Anything the
      tests need at run time has to be in a `BeforeAll`. A setup file written for 6.1 has no
      `BeforeAll` and stops working without a warning - see
      [The Setup File Needs a BeforeAll](#the-setup-file-needs-a-beforeall) below.
- [ ] **`Should-BeFasterThan` and `Should-BeSlowerThan` throw on input they cannot measure.** Both
      take a `[scriptblock]` to run or a `[timespan]` to compare. On 6.1 a string, a number, or
      `$null` fell through and the test passed having asserted nothing; on 6.2 it fails with
      `Expected a [scriptblock] to measure or a [timespan] to compare, but got [string] '...'`. A
      test that starts failing here was never measuring - fix it to pipe the scriptblock.
- [ ] **A configuration value of the wrong type throws while the configuration is built.**
      `Run.Parallel = 'yes'` fails with `Run.Parallel expects a bool, but got the string 'yes'`.
      This bites `psd1` and JSON files first, where a boolean written in quotes arrives as a string.
      An `int` for a `decimal` is still accepted, and a `$null` value still means "not set".
- [ ] **A key that matches no option is reported.** `Invoke-Pester` warns once:
      `WARNING: Ignoring configuration keys 'Run.Paralel', there are no such options`. The list is
      also on the object as `$config.GetUnknownKeys()`, which is the thing to gate on in CI since a
      warning does not fail a job. Before 6.2 a misspelled key was silently ignored.
- [ ] **Assertions name themselves in the collection-on-`-Expected` error.** The message that read
      "is not allowed by this assertion" now reads "is not allowed by Should-Be". Anything matching
      on that text sees a new string.
- [ ] **Stray output from a setup file no longer warns.** It cannot escape the container any more,
      so a pipeline that grepped for that warning finds nothing.

### The Setup File Needs a BeforeAll

On 6.1 everything in `Pester.BeforeContainer.ps1` sat at top level and reached the tests. On 6.2 the
file follows the same rule as a test file: top-level code runs at discovery, `BeforeAll` runs before
the tests. Measured on 6.2 with the 6.1 shape, in both sequential and parallel runs:

| Top-level statement in the setup file | Visible at discovery | Visible to the tests |
| --- | --- | --- |
| `Import-Module` | yes | yes - module state is session-wide, not because the file ran |
| `. ./Bootstrap.ps1` defining a function | yes | **no** - `CommandNotFoundException` |
| `$script:Var = ...` | yes | **no** - reads as `$null` |

Nothing warns. Wrap the run-time part:

```powershell
# before (6.1)
Import-Module "$PSScriptRoot/Source/MyModule.psd1" -Force
. "$PSScriptRoot/Tests/TestHelpers/Bootstrap.ps1"

# after (6.2)
BeforeAll {
    Import-Module "$PSScriptRoot/Source/MyModule.psd1" -Force
    . "$PSScriptRoot/Tests/TestHelpers/Bootstrap.ps1"
}
```

Keep a top-level copy only for what discovery itself needs - a helper command used inside a
`-ForEach` or `BeforeDiscovery`. `BeforeAll` in a setup file does nothing on 6.1 - none of its setup
reaches discovery or the tests - so one file cannot serve both versions; the version floor moves
with this change.

### Restriction Lifted

A block can have as many `BeforeAll`, `AfterAll`, `BeforeEach` and `AfterEach` blocks as you want.
They all run - setups in declaration order, teardowns in reverse - so setup can be grouped by what it
sets up:

```powershell
Describe 'Get-User' {
    BeforeAll { Import-Module "$PSScriptRoot/../src/MyModule.psd1" -Force }
    BeforeAll { $script:user = New-TestUser -Name 'jakub' }
    AfterAll  { Remove-TestUser -Name 'jakub' }
    AfterAll  { Remove-Module MyModule -Force }
}
```

6.0 and 6.1 threw on the second one. A CI hint keyed on that error, or a lint rule enforcing one
block per scope, can go.

### What Is New

| Addition | Where |
| --- | --- |
| `Pester.BeforeContainer.ps1` in any folder under `Run.RepoRoot` - every one from the root down applies, outermost first | [Pester Configuration Guide](./pester-configuration.md#folder-scoped-setup-62) |
| `#pester:no-inherit` - a folder's setup file opts out of everything above it | [Pester Configuration Guide](./pester-configuration.md#folder-scoped-setup-62) |
| `$container.BeforeContainerFile` - which setup files applied, on the result object | [Test Execution Guide](./test-execution.md#result-object-reference) |
| `Should-BeString` prints every differing region with line numbers for strings over 10 lines or 120 characters | [Assertion Guide](./assertion-guide.md#long-strings-get-a-real-diff) |
| `$config.GetUnknownKeys()` - configuration keys that matched no option | [Pester Configuration Guide](./pester-configuration.md#dynamic-configuration-loading) |
| `Run.Parallel` on Windows PowerShell 5.1 (experimental) - the runner moved to a runspace pool | [Test Execution Guide](./test-execution.md#parallel-test-execution-experimental) |
| A parallel run throws when a worker's file goes missing, and a failed worker no longer aborts the rest under `$ErrorActionPreference = 'Stop'` | [Test Execution Guide](./test-execution.md#a-lost-file-is-an-error) |
| Failures point at the line that caused them - errors from inside Pester keep their stack trace, and an assertion failing inside a helper reports the helper's caller too | Output only |

### Behavior Worth Knowing About

None of these fail an existing suite, but they change what you see:

- **`Run.RepoRoot` is resolved from the session's current location** when you did not set it.
  `New-PesterConfiguration` still shows the .NET process working directory on the object, but
  `Invoke-Pester` re-resolves from `$PWD` before the run, so a session that started elsewhere and
  then changed into the repository now finds its setup files. Setting it explicitly still wins.
- **`Run.SkipRun` applies the setup-file chain.** A discovery-only pass - the path the VS Code Test
  Explorer uses - used to skip the setup files, so a `-ForEach` over data they provided came back
  empty in the explorer and populated in a real run.
- **A `BeforeAll` that throws reports the real error.** 6.1 reported _A 'break' or 'continue'
  statement with a label that does not match any enclosing loop escaped from your code_ and
  discarded the exception, so a database being down read as a misspelled loop label.
- **`Invoke-Pester` keeps its `-1` exit code when it fails internally.** It could overwrite it with
  `$null` when the failure came before the run was created, or with `0` when a plugin failed after
  an otherwise successful run.
- **Pester imports on PowerShell 7.4.0 to 7.4.5 again.** 6.0 and 6.1 failed there with
  `Cannot convert "PesterConfigurationDeserializer" from String to Type`, because the `net8.0`
  assembly referenced a newer `System.Management.Automation` than those releases carry.
- **Stack traces from Pester's own C# code no longer carry the build agent's path.**
  `D:\a\1\s\src\csharp\Pester\...` became `/_/src/csharp/Pester/...`, and the build is reproducible
  as a side effect.
- **The `TestRegistry` retry message is a debug message now.** `IO exception during a TestRegistry
  operation, retrying.` no longer appears as a warning when the retry recovers.

### Verifying The Upgrade

```powershell
# 1. Find setup files with top-level statements other than BeforeAll/AfterAll -
#    those run at discovery only on 6.2
Get-ChildItem -Recurse -Filter Pester.BeforeContainer.ps1 | ForEach-Object {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
    $topLevel = @($ast.EndBlock.Statements | Where-Object {
        $first = $_.PipelineElements[0]
        -not ($first -is [System.Management.Automation.Language.CommandAst] -and
              $first.GetCommandName() -in 'BeforeAll', 'AfterAll')
    })
    if ($topLevel.Count -gt 0) {
        "$($_.FullName): $($topLevel.Count) top-level statement(s) run at discovery only"
    }
}

# 2. Confirm which setup files each test file actually got
$result = Invoke-Pester -Path ./Tests -PassThru -Output None
$result.Containers | ForEach-Object { "$($_.Item.Name): $($_.BeforeContainerFile -join ', ')" }

# 3. Find timing assertions whose left side does not end in a scriptblock's closing brace
Get-ChildItem -Recurse -Filter *.Tests.ps1 |
    Select-String -Pattern '[^}\s]\s*\|\s*Should-Be(Faster|Slower)Than' |
    Select-Object Path, LineNumber, Line

# 4. Fail on configuration keys that match no option
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile ./Tests/PesterConfiguration.psd1)
if ($config.GetUnknownKeys()) { throw "Unknown keys: $($config.GetUnknownKeys() -join ', ')" }
```
