---
applyTo: "**/*.ps1,**/*.psm1"
description: 'Automatic style guide enforcement'
---

# PowerShell Style Guide Enforcement

Automatically enforce PowerShell community style guidelines in all code generation.

> **Worked example**: every file under
> [Documentation/Examples](../../Documentation/Examples/) is written to these rules and passes the
> repository's own quality gates. When the wording here is ambiguous, match the examples.

## Mandatory Style Patterns

### Code Formatting

- **Brace Style**: One True Brace Style (opening brace at end of line)
- **Indentation**: 4 spaces, never tabs
- **Line Length**: Maximum 115 characters
- **Blank Lines**: 2 blank lines before functions, 1 between methods

A team that wants these checked mechanically does not need a settings file - PSScriptAnalyzer ships
`CodeFormattingOTBS`, which already configures the brace style, 4-space indentation, whitespace and
assignment alignment above:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings CodeFormattingOTBS
```

The 115-character limit is the one rule it does not include; add `PSAvoidLongLines` if the team
wants it enforced. Adopting either is their choice - these standards describe the practices, not the
audit configuration.

### Parameter Formatting

```powershell
# Correct parameter block formatting
param(
    [Parameter(Mandatory = $true,
               ValueFromPipeline = $true,
               ValueFromPipelineByPropertyName = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ComputerName,

    [Parameter()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential = [System.Management.Automation.PSCredential]::Empty
)
```

### Operator Spacing

```powershell
# Correct spacing around operators
$result = $value1 + $value2
$condition = ($status -eq 'Running') -and ($service -ne $null)

# Correct parameter spacing
Get-Process -Name "powershell" -ComputerName $servers
```

### Anti-Patterns to Avoid

```powershell
# Avoid backticks for line continuation
# Instead of:
Get-WmiObject -Class Win32_LogicalDisk `
              -Filter "DriveType=3" `
              -ComputerName $server

# Use splatting:
$params = @{
    Class = 'Win32_LogicalDisk'
    Filter = 'DriveType=3'
    ComputerName = $server
}
Get-WmiObject @params

# Avoid Write-Host unless specifically needed for colored output
# Use Write-Output, Write-Verbose, Write-Information instead
```

## Automatic Style Corrections

When generating code, automatically apply:

1. Convert aliases to full command names
2. Add proper spacing around operators and parameters
3. Format parameter blocks with proper alignment
4. Use approved verbs and PascalCase naming
5. Add comprehensive comment-based help templates
6. Implement proper error handling patterns
7. Include correlation ID tracking in functions
