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
└── Public/
    └── Get-ExampleData.ps1          # The only exported function
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

## Patterns demonstrated

| Pattern | Where |
|---|---|
| Approved verb, descriptive `[OutputType]` | `Public/Get-ExampleData.ps1` |
| Pipeline input via `ValueFromPipeline` | `Public/Get-ExampleData.ps1` |
| Correlation ID generated once, passed through | All three files |
| `$_` in `catch`, not `$Error[0]` | `Public/Get-ExampleData.ps1` |
| Per-item failure that does not abort the batch | `Public/Get-ExampleData.ps1` |
| Class with validation and behaviour | `Classes/ExampleClass.ps1` |

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
