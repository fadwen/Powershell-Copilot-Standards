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
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0' }
```

## Upgrade Checklist

Work through these in order. Items 1-3 are hard breakages that fail immediately; the rest are
behavior changes that can pass silently and mislead.

- [ ] **1. Replace `Assert-MockCalled` and `Assert-VerifiableMock`.** Both were **removed**. Use
      `Should -Invoke` / `Should -InvokeVerifiable`, or the new `Should-Invoke` / `Should-NotInvoke`.
- [ ] **2. Remove duplicate setup/teardown blocks.** Two `BeforeAll` (or `BeforeEach`, `AfterAll`,
      `AfterEach`) in the same block now **throw** instead of being silently allowed. Merge them.
- [ ] **3. Remove `-Focus` and `-Pending`.** `Describe`/`Context`/`It` no longer accept `-Focus`, and
      the `Focus` property is gone from the result object. `Set-ItResult -Pending` is gone - use
      `-Skipped` or `-Inconclusive`. Use `-Skip`, tags, or `Filter` to select which tests run.
- [ ] **4. Audit every `-ForEach` / `-TestCases` that can produce an empty set.** `$null` or `@()`
      now **fails discovery** (`Run.FailOnNullOrEmptyForEach`, on by default). Opt out per block or
      test with `-AllowNullOrEmptyForEach`, or fix the generator so it cannot be empty.
- [ ] **5. Make every test file self-contained.** Discovery and run now happen per file - a module
      imported at discovery time in one file is not guaranteed to be loaded when another file is
      discovered. See below.
- [ ] **6. Check for a literal tag named `None`.** `None` is now a reserved filter value meaning
      "tests with no tags". Rename any real tag called `None`.
- [ ] **7. Review code coverage settings.** Profiler-based coverage is now the default; set
      `CodeCoverage.UseBreakpoints = $true` only if you depend on breakpoint-based numbers. The
      `CoverageGutters` output format was **removed** - use `JaCoCo` or `Cobertura`.
- [ ] **8. Check test and block names containing `<...>`.** Only `<...>` templates are expanded now,
      and their contents are evaluated as full PowerShell expressions.
- [ ] **9. Check for `*.Tests.ps1` in hidden or dot-prefixed folders.** These are now discovered and
      run. Add `Run.ExcludePath` entries for any you do not want picked up.
- [ ] **10. Adopt `Should-*` assertions in new tests.** Optional and additive - see
      [Assertion Guide](./assertion-guide.md). Do not set `Should.DisableV5 = $true` until the whole
      suite is migrated.

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

**Shared bootstrap.** When several files need the same setup, use `Run.BeforeContainer` - one or
more scriptblocks that run before **every** test file is discovered and run, in both serial and
parallel runs:

```powershell
$config.Run.BeforeContainer = { . './setup.ps1' }
```

If you do not set it, Pester looks for a single `Pester.BeforeContainer.ps1` in the repository root
(`Run.RepoRoot`, found from the nearest `.git` directory) and dot-sources it when present. Setting
`Run.BeforeContainer` overrides the convention file.

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
| `Run.BeforeContainer` | New. Scriptblocks run before every file is discovered and run |
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
Invoke-Pester -Path ./Tests -TagFilter 'None'   # should return zero tests in a well-tagged suite
```

If you used `None` as a literal tag, rename it - filtering by it now also selects every untagged
test.

## Parallel Execution (Experimental)

See [Test Execution Guide](./test-execution.md) for the full treatment. In short:

```powershell
$config.Run.Parallel = $true
$config.Run.ParallelThrottleLimit = 4   # 0 (default) uses all processors
```

Requires PowerShell 7+ and file-based containers. Falls back to a sequential run **with a warning**
on Windows PowerShell 5.1, for in-memory `ScriptBlock` containers, when `CodeCoverage` is enabled,
and when `Run.SkipRemainingOnFailure = 'Run'`.

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

# 4. Discovery-only pass - surfaces duplicate setup blocks and empty -ForEach without running tests
$config = New-PesterConfiguration
$config.Run.Path = './Tests'
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
Invoke-Pester -Configuration $config

# 5. Find untagged tests
Invoke-Pester -Path ./Tests -TagFilter 'None'
```

Step 4 is the highest-value check: it walks every file through discovery, so duplicate
`BeforeAll`/`AfterEach` blocks and empty `-ForEach` sets throw there without paying for a full run.
