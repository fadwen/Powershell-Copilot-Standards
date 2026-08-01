---
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
tools: ['codebase', 'githubRepo']
description: 'PowerShell version baseline, support lifecycle, and version-dependent language/cmdlet features'
---

# PowerShell Version Baseline

Which PowerShell version to target, and which features are safe to emit at that target.
Verified against the Microsoft support lifecycle as of **2026-08-01**.

## Support lifecycle

| Version | Type | Released | End of support | Runtime |
| --- | --- | --- | --- | --- |
| **7.6** | **LTS - current target** | 18-Mar-2026 | 14-Nov-2028 | .NET 10 |
| 7.5 | Stable | 23-Jan-2025 | **10-Nov-2026** | .NET 9 |
| 7.4 | LTS (previous) | 16-Nov-2023 | **10-Nov-2026** | .NET 8 |
| 5.1 | Windows component | Aug-2016 | Windows lifecycle | .NET Framework 4.x |

Everything below 7.4 is retired and receives no security updates. Never generate code or CI
matrices targeting PowerShell 6.x, 7.0-7.3.

> **Act on this:** PowerShell 7.4 and 7.5 both go out of support on **10-Nov-2026**. Any project
> pinned to 7.4 or 7.5 needs a 7.6 upgrade planned now. Recommend 7.6 for all new work.

Windows PowerShell 5.1 is not deprecated - it ships with Windows and is supported under the
Windows lifecycle - but it receives no new features. Treat it as a compatibility target, never
as the target you optimize for.

## Choosing a target

Ask which applies before generating code:

- **Cross-version modules** (shipping to unknown estates) - target `5.1` with
  `CompatiblePSEditions = @('Desktop', 'Core')`. Gate 7.x-only features behind version checks.
- **Modern-only automation** (containers, CI, greenfield) - target **7.6** with
  `CompatiblePSEditions = @('Core')`. Do not carry 5.1 compatibility cost for no reason.
- **Windows-estate tooling** that must run in-box on servers without pwsh installed - target `5.1`.

Declare the target explicitly, at the top of scripts and in the module manifest:

```powershell
#requires -Version 7.6
```

```powershell
@{
    PowerShellVersion    = '7.6'
    CompatiblePSEditions = @('Core')
}
```

Use `#requires -Version 7.4` only when you have verified the code avoids every 7.5/7.6 feature
listed below. `#requires -Version 7.0` is obsolete - that version is retired; if you mean "any
PowerShell 7", the lowest supported floor is `7.4`, and after 10-Nov-2026 it is `7.6`.

## Version-dependent features

Do not emit these unless the declared target supports them.

### PowerShell 7.5+

| Feature | Notes |
| --- | --- |
| `ConvertTo-CliXml` / `ConvertFrom-CliXml` | Serialize to CliXml without a temp file. Replaces `Export-Clixml` to a scratch path. |
| `ConvertFrom-Json -DateKind` | Controls how date strings deserialize (`Local`, `Utc`, `Offset`, `String`). Use `Utc` or `Offset` for audit data. |
| `Test-Json -IgnoreComments` / `-AllowTrailingCommas` | Validate JSONC-style config without pre-stripping. |
| `Resolve-Path -Force` / `Convert-Path -Force` | Wildcard resolution that includes hidden files. |
| `New-Guid -Empty` / `-InputObject` | Empty GUID and string-to-GUID conversion without a cast. |
| `Get-Process -IncludeUserName` | No longer requires admin. |
| Error `ConciseView` `RecommendedAction` | Surfaced in error output. |

### PowerShell 7.6+

| Feature | Notes |
| --- | --- |
| `Get-Command -ExcludeModule` | Filter discovery without post-filtering the pipeline. |
| `Register-ArgumentCompleter -NativeFallback` | Register one cover-all completer for native commands. |
| `Get-Clipboard -Delimiter` | Split clipboard content on read. |
| `PSForEach()` / `PSWhere()` | Aliases for the `.Foreach()` / `.Where()` intrinsic methods. Prefer these when `.Where()` collides with a LINQ-style method on the piped type. |
| `PipelineStopToken` on `Cmdlet` | For binary cmdlets - signaled when the pipeline stops. |

### Promoted from experimental (now always on)

Do not tell users to enable these with `Enable-ExperimentalFeature`; they are mainstream.

- **7.5**: `PSCommandNotFoundSuggestion`, `PSCommandWithArgs`, `PSModuleAutoLoadSkipOfflineFiles`
- **7.6**: `PSFeedbackProvider`, `PSNativeWindowsTildeExpansion`, `PSRedirectToVariable`,
  `PSSubsystemPluginModel`

`PSRedirectToVariable` means redirection to a variable is now valid syntax in 7.6:

```powershell
# 7.6+ - capture a stream without a temp file or subexpression
Get-Item .\missing 2>&1 > variable:capturedErrors
```

## Breaking changes to code around

These changed behavior in supported versions. Generated code must not depend on the old behavior.

### PowerShell 7.6

- **`ThreadJob` module renamed to `Microsoft.PowerShell.ThreadJob`.** `Start-ThreadJob` itself is
  unchanged, so only module-qualified calls and manifest dependencies break.

  ```powershell
  # ❌ Breaks on 7.6
  ThreadJob\Start-ThreadJob -ScriptBlock { ... }
  RequiredModules = @(@{ ModuleName = 'ThreadJob'; ModuleVersion = '2.0.3' })

  # ✅
  Microsoft.PowerShell.ThreadJob\Start-ThreadJob -ScriptBlock { ... }
  RequiredModules = @(@{ ModuleName = 'Microsoft.PowerShell.ThreadJob'; ModuleVersion = '2.2.0' })
  ```

  Simplest fix: call `Start-ThreadJob` unqualified and let module autoloading resolve it.

- **`Join-Path -ChildPath` accepts `string[]`.** Multi-segment joins now work in one call, but
  code that relied on an array argument stringifying into a single segment breaks.

  ```powershell
  # 7.6+ - one call instead of nesting
  Join-Path $PSScriptRoot 'Private' 'Helpers' 'Write-Log.ps1'
  ```

- **`WildcardPattern.Escape` escapes lone backticks correctly.** Code that double-escaped to work
  around the old bug now over-escapes.

### PowerShell 7.5

- **`ConvertTo-Json` serializes `BigInteger` as a number**, not an object. Consumers expecting the
  old object shape break.
- **`Test-Path -OlderThan` and `-NewerThan` both apply** when specified together. Previously
  `-OlderThan` was silently ignored - a date-range check that appeared to work was not filtering.
- **`New-FileCatalog -CatalogVersion` defaults to 2.** Pass `-CatalogVersion 1` explicitly if a
  downstream validator still requires v1.
- **`Select-String` `LineNumber` is now `ulong`.** Strict-typed downstream assignments to `int`
  break.

## Array accumulation - version-dependent guidance

This is the most commonly miscited PowerShell performance rule, and it changed in 7.5.

PowerShell 7.5 optimized `+=` on object arrays. It is no longer the pathological case it is in
5.1 and 7.4 - it is now **faster than `List<T>.Add()`** for that scenario. The blanket advice
"never use `+=`" is stale for 7.5+.

What did not change: **assigning the loop output directly is still fastest in every version**, by
a wide margin. Prefer it regardless of target.

```powershell
# ✅ Best on every version - no per-iteration allocation at all
$results = foreach ($item in $collection) {
    Get-ProcessedItem -Item $item
}

# ✅ Also fine - pipeline output
$results = $collection | ForEach-Object { Get-ProcessedItem -Item $_ }
```

When you must accumulate conditionally and cannot assign loop output directly:

```powershell
# ✅ Portable across 5.1 and 7.x - use the generic List, not ArrayList
$results = [System.Collections.Generic.List[object]]::new()
foreach ($item in $collection) {
    if (Test-ItemRelevant -Item $item) {
        $results.Add((Get-ProcessedItem -Item $item))
    }
}
```

Rules for generated code:

- Never generate `[System.Collections.ArrayList]`. It is a non-generic .NET 1.1 type kept only for
  back-compat, it boxes values, and it forces `[void]` noise on every `.Add()`. Use
  `[System.Collections.Generic.List[object]]` or a typed `List[T]`.
- Do not flag `+=` as a defect when the declared target is 7.5+ and the collection is small or the
  loop is not hot. Flag it when the target includes **5.1 or 7.4**, where it remains O(n²).
- Do flag `+=` in any loop over an unbounded collection, on any version - direct assignment is
  still the correct pattern.

## Module installation - use PSResourceGet

`Microsoft.PowerShell.PSResourceGet` (v1.2.0 ships in 7.6) is the supported package client.
PowerShellGet v2 `Install-Module` / `Find-Module` still work via the compatibility layer, but new
instructions should use the PSResourceGet verbs.

```powershell
# ✅ Preferred
Install-PSResource -Name Pester -Scope CurrentUser -TrustRepository
Find-PSResource -Name PSScriptAnalyzer
Publish-PSResource -Path ./MyModule -ApiKey $env:NUGET_KEY

# ⚠️ PowerShellGet v2 - still functional, use only when targeting 5.1 without PSResourceGet installed
Install-Module -Name Pester -Scope CurrentUser -Force -SkipPublisherCheck
```

On Windows PowerShell 5.1, `Microsoft.PowerShell.PSResourceGet` is not in-box and must be
installed first with `Install-Module`. Scripts that must bootstrap on both should detect:

```powershell
if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
    Install-PSResource -Name $Module -Scope CurrentUser -TrustRepository
}
else {
    Install-Module -Name $Module -Scope CurrentUser -Force -SkipPublisherCheck
}
```

## Detecting version at runtime

```powershell
# ✅ Compare the whole version, not just Major - 7.4 and 7.6 both have Major 7
if ($PSVersionTable.PSVersion -ge [version]'7.6') {
    # 7.6+ path
}

# ✅ $IsWindows is undefined on 5.1, which is always Windows
$onWindows = $PSVersionTable.PSVersion.Major -eq 5 -or $IsWindows

# ❌ Wrong - true on 7.0 through 7.6 alike
if ($PSVersionTable.PSVersion.Major -ge 7) { }
```

Report the runtime .NET version when diagnosing platform-specific behavior:

```powershell
[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
```

## Tooling versions

| Tool | Current | Notes |
| --- | --- | --- |
| PSScriptAnalyzer | 1.25.0 | Released 20-Mar-2026 |
| Pester | 6.x | See [pester.instructions.md](pester.instructions.md) |
| Microsoft.PowerShell.PSResourceGet | 1.2.0 | In-box with 7.6 |
| PSReadLine | 2.4.5 | In-box with 7.6 |
| Microsoft.PowerShell.ThreadJob | 2.2.0 | In-box with 7.6, renamed from `ThreadJob` |
