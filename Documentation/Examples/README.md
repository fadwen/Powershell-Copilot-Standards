# Examples

Working code demonstrating the standards in this repository. Every file here runs, and everything
except the deliberate anti-pattern demonstration is covered by tests.

## What is here

| Example | Demonstrates |
|---|---|
| [Basic-Function-Example.ps1](./Basic-Function-Example.ps1) | A complete advanced function: pipeline input, parameter validation, correlation IDs, per-item error handling, and a named `[OutputType]` |
| [Module-Structure-Example/](./Module-Structure-Example/) | A minimal working module - the Public/Private/Classes layout and the export boundary it creates |
| [Testing-Examples/](./Testing-Examples/) | Pester 6 tests for `Basic-Function-Example.ps1`, including CIM mocking and `-RemoveParameterType` |
| [Test-QualityGates.ps1](./Test-QualityGates.ps1) | **Intentional anti-patterns.** Shows what the quality gates catch. Not a model to copy |
| [Configuration/DefaultConfiguration.psd1](./Configuration/DefaultConfiguration.psd1) | A configuration data file: environment settings, validation thresholds, and logging targets |

## Start with the function example

[Basic-Function-Example.ps1](./Basic-Function-Example.ps1) is the densest single file:

```powershell
. .\Basic-Function-Example.ps1

Get-BasicServerInfo -ComputerName 'SERVER01' -WhatIf
'SERVER01', 'SERVER02' | Get-BasicServerInfo -Verbose
```

It shows:

- `[OutputType('BasicServerInfo')]` with a matching `PSTypeName` on the output, rather than
  `[OutputType([PSCustomObject])]`, which tells a caller nothing about the shape returned
- A correlation ID generated once in `begin` and carried through every message
- `$_` in `catch`, and `continue` so one unreachable host does not abort the batch
- `ShouldProcess` support, so `-WhatIf` works

## Then the module

[Module-Structure-Example/](./Module-Structure-Example/) is deliberately small. Its point is not the
code but the boundary: `FunctionsToExport` names the public surface, so the private helper stays
internal and can change without a breaking release. Classes load before the functions that return
them.

## The anti-pattern file

[Test-QualityGates.ps1](./Test-QualityGates.ps1) is the one file here that intentionally breaks the
standards - `Write-Host`, `$Error[0]` in a catch, a non-approved verb, string building in a loop. It
exists so the quality gates have something to catch, and the CI workflows exclude it from production
analysis by name for that reason.

Its tests in [Test-QualityGates.Tests.ps1](./Test-QualityGates.Tests.ps1) document that behaviour
rather than endorsing it.

## Related

- [PowerShell Best Practices](../PowerShell-Best-Practices.md) - the reasoning behind these patterns
- [Templates/Powershell-Module](../../Templates/Powershell-Module/) - a fuller starting point to copy
- [Version baseline](../../.github/instructions/powershell-version.instructions.md) - which PowerShell
  version to target, and why
