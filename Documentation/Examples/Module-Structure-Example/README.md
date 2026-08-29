# Module Structure Example

A minimal but working module showing the layout the standards expect, and - more importantly - the
export boundary that layout exists to create.

Small enough to read in one sitting. For a fuller starting point to copy, use
[Templates/Powershell-Module](../../../Templates/Powershell-Module/).

## Layout

```text
Module-Structure-Example/
├── ModuleExample.psd1     # Manifest. Declares the public surface explicitly
├── ModuleExample.psm1     # Loader. Classes, then private, then public
├── Classes/
│   └── ExampleClass.ps1   # ExampleServiceResult - a named output type
├── Private/
│   └── Connect-ExampleService.ps1   # Internal, never exported
├── Public/
│   └── Get-ExampleData.ps1          # The only exported function
├── docs/                            # PlatyPS Markdown - the help source you edit
│   └── ModuleExample/
│       ├── ModuleExample.md         # Module page
│       └── Get-ExampleData.md       # Command help, canonical
└── en-US/
    └── ModuleExample-Help.xml       # Compiled MAML - what Get-Help reads
```

## Why the folders exist

**Load order is not arbitrary.** `ModuleExample.psm1` loads `Classes/` first, because
`Get-ExampleData` returns an `ExampleServiceResult` and the type must exist before the function
referencing it is defined. Private functions load next, so public functions can call them.

**The manifest controls export, not the loader.** `FunctionsToExport = @('Get-ExampleData')` names
the public surface. `Connect-ExampleService` is dot-sourced and callable inside the module, but is
never exported - so its signature can change without a breaking release. A wildcard export would
remove that freedom and slow module autoloading.

**A class replaces `[PSCustomObject]`.** `[OutputType('ExampleServiceResult')]` tells a caller what
they receive and gives them IntelliSense. The standards discourage `[OutputType([PSCustomObject])]`
because it communicates nothing.

**Help is generated, not hand-written.** `Get-ExampleData.ps1` keeps only `.EXTERNALHELP` and a
one-line `.SYNOPSIS`; everything a user sees lives in `docs/ModuleExample/Get-ExampleData.md` and
compiles to `en-US/ModuleExample-Help.xml`. Import the module and run
`Get-Help Get-ExampleData -Full` to see the compiled help served.

Rebuild after editing the Markdown:

```powershell
Import-Module Microsoft.PowerShell.PlatyPS

Measure-PlatyPSMarkdown -Path ./docs/ModuleExample/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Import-MarkdownCommandHelp -Path {$_.FilePath} |
    Export-MamlCommandHelp -OutputFolder ./maml -Force

Copy-Item ./maml/ModuleExample/ModuleExample-Help.xml ./en-US/ -Force
```

`.EXTERNALHELP` sits **inside** the `<# #>` block deliberately. As a bare `#` comment preceded by
ordinary prose it stops being recognized, and `Get-Help` silently falls back to the stub synopsis
instead of the compiled help. See
[platyps.instructions.md](../../../.github/instructions/platyps.instructions.md).

## Patterns demonstrated

| Pattern | Where |
|---|---|
| Approved verb, descriptive `[OutputType]` | `Public/Get-ExampleData.ps1` |
| Pipeline input via `ValueFromPipeline` | `Public/Get-ExampleData.ps1` |
| Correlation ID generated once, passed through | All three files |
| `$_` in `catch`, not `$Error[0]` | `Public/Get-ExampleData.ps1` |
| Per-item failure that does not abort the batch | `Public/Get-ExampleData.ps1` |
| Class with validation and behaviour | `Classes/ExampleClass.ps1` |
| A fallible call, so the catch is reachable | `Private/Get-ExampleServiceStatus.ps1` |

## Tests

[Tests/ModuleExample.Tests.ps1](./Tests/ModuleExample.Tests.ps1) covers the module contract, the
class, both private helpers via `InModuleScope`, and the per-item failure path.

`Get-ExampleServiceStatus` exists so that failure path is real. Without a fallible call inside the
loop, a `catch` block in an example is decorative - it looks like resilience, but nothing can
exercise it and no test can prove it works.

## Trying it

```powershell
Import-Module ./ModuleExample.psd1 -Force

Get-ExampleData -ServiceName 'Billing'
'Billing', 'Identity' | Get-ExampleData -Environment Test -Verbose

# The private helper is deliberately not available
Get-Command Connect-ExampleService -ErrorAction SilentlyContinue   # returns nothing
```

There is no real service behind this module. `Connect-ExampleService` sleeps briefly to stand in for
connection latency, and status is derived from the environment so the result set is not uniform.
