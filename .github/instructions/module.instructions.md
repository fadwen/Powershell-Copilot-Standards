---
mode: 'agent'
applyTo: "**/*.psm1,**/*.psd1,**/Public/*.ps1,**/Private/*.ps1"
tools: ['codebase', 'githubRepo']
description: 'Creates enterprise-grade PowerShell modules with proper structure, security, and functionality'
---

# PowerShell Module Development Assistant

Create comprehensive, enterprise-grade PowerShell modules that follow organizational standards, implement security best
practices, and provide scalable functionality for business operations.

## Module Planning and Design

### Initial Requirements Gathering

Collect essential information for module development:

#### Module Specifications

- **Module Name**: Following PowerShell naming conventions (noun should be singular)
- **Primary Purpose**: Clear business value and functional scope
- **Target Audience**: System administrators, developers, end users, or automation systems
- **Functionality Scope**: Core features and capabilities to implement
- **Dependencies**: Required PowerShell modules and external systems
- **Security Requirements**: Authentication, authorization, and data protection needs
- **Performance Targets**: Expected load, scalability, and response time requirements

#### Technical Requirements

- **PowerShell Versions**: PowerShell 7.6 (LTS, default for new modules), or 5.1 + 7.6 when the module must run on
  Windows estates without pwsh. Do not target 7.4/7.5 alone — both lose support 10-Nov-2026
- **Platform Support**: Windows, Linux, macOS, or cross-platform
- **Integration Points**: External APIs, databases, file systems, or services
- **Deployment Method**: PowerShell Gallery, internal repository, or direct installation

## Module Structure Generation

> **Worked example**:
> [Documentation/Examples/Module-Structure-Example](../../Documentation/Examples/Module-Structure-Example/)
> is a small working module implementing everything in this section - the folder layout, the load
> order in `ModuleExample.psm1`, an explicit `FunctionsToExport`, a class used as a named output
> type, and a private helper that is never exported. Read it before generating a new module; prefer
> matching its shape over inventing one.

### Standard Module Directory Structure

Create the complete module structure following enterprise standards:

```text
ModuleName/
├── ModuleName.psd1                 # Module manifest
├── ModuleName.psm1                 # Root module file
├── Public/                         # Exported functions
│   ├── Get-ModuleFunction.ps1
│   ├── Set-ModuleConfiguration.ps1
│   └── Invoke-ModuleProcess.ps1
├── Private/                        # Internal functions
│   ├── Test-InternalValidation.ps1
│   └── Connect-InternalService.ps1
├── Classes/                        # PowerShell classes
│   ├── ModuleConfiguration.ps1
│   └── ModuleException.ps1
├── Data/                          # Static data and configuration
│   ├── DefaultConfiguration.psd1
│   └── ErrorCodes.psd1
├── Tests/                         # Comprehensive test suite
│   ├── Unit/
│   ├── Integration/
│   └── Performance/
├── docs/                          # PlatyPS command help - Markdown source, committed
│   └── ModuleName/
│       ├── ModuleName.md          # module page
│       └── Get-ModuleFunction.md  # one file per exported command
├── en-US/                         # Compiled help, packaged with the module
│   ├── ModuleName-Help.xml        # built by Export-MamlCommandHelp - never hand-edited
│   └── about_ModuleName.help.txt  # hand-written conceptual topic
├── Troubleshooting/              # Organized troubleshooting docs
│   ├── Common/
│   ├── Security/
│   ├── Performance/
│   └── Integration/
├── Documentation/                # Project documentation
├── Configuration/               # Environment configurations
├── Scripts/                    # Utility scripts
└── README.md                   # Main documentation
```

`docs/` and `en-US/` are generated and maintained with **Microsoft.PowerShell.PlatyPS** — see
[platyps.instructions.md](./platyps.instructions.md). Every function in `Public/` must carry
`.EXTERNALHELP ModuleName-Help.xml`, or the shipped MAML is silently ignored in favour of the
comment block.

### Module Manifest Creation

Generate comprehensive module manifest (ModuleName.psd1). For a complete, valid manifest see
[ModuleExample.psd1](../../Documentation/Examples/Module-Structure-Example/ModuleExample.psd1) -
note that `FunctionsToExport` names each public function explicitly, which is what keeps private
helpers internal:

```powershell
@{
    # Basic Module Information
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = '$(New-Guid)'
    Author = 'Jeffrey Stuhr'
    CompanyName = 'Organization Name'
    Copyright = '(c) $(Get-Date -Format yyyy) Organization Name. All rights reserved.'
    Description = 'Comprehensive description of module functionality and business value'

    # PowerShell Version Requirements
    # Default to 7.6 (LTS). Switch to '5.1' + @('Desktop','Core') only when Windows PowerShell
    # support is an explicit requirement — see instructions/powershell-version.instructions.md
    PowerShellVersion = '7.6'
    CompatiblePSEditions = @('Core')

    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'PSFramework'; ModuleVersion = '1.7.270' }
    )

    # Module Components
    FunctionsToExport = @('Get-ModuleFunction', 'Set-ModuleConfiguration')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    # PowerShell Gallery Metadata
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'Enterprise', 'Automation', 'Management')
            LicenseUri = 'https://github.com/organization/modulename/blob/main/LICENSE'
            ProjectUri = 'https://github.com/organization/modulename'
            IconUri = 'https://github.com/organization/modulename/raw/main/Assets/icon.png'
            ReleaseNotes = 'Initial release with core functionality'
            RequireLicenseAcceptance = $false
        }
    }

    # Help Information
    # Only set this if you actually publish an Updatable Help package to that location.
    # Update-Help reports an error against a HelpInfoURI with no HelpInfo.xml behind it.
    # Shipping MAML in en-US/ does not require this key.
    HelpInfoURI = 'https://docs.organization.com/powershell/modulename'
}
```

### Root Module Implementation

Create optimized root module file (ModuleName.psm1). Load order matters: classes first, then private
functions, then public ones - see
[ModuleExample.psm1](../../Documentation/Examples/Module-Structure-Example/ModuleExample.psm1) for a
working loader.

```powershell
# Match the manifest's PowerShellVersion. This template targets 7.6; use 5.1 only
# when the module is built for Windows PowerShell compatibility.
#Requires -Version 7.6

# Module initialization
$ModuleRoot = $PSScriptRoot
Write-Verbose "Initializing module: $($MyInvocation.MyCommand.Module.Name)"

# Import module components in order
try {
    # Load Classes first (dependencies for functions)
    $classFiles = Get-ChildItem -Path "$ModuleRoot\Classes\*.ps1" -ErrorAction SilentlyContinue
    foreach ($class in $classFiles) {
        Write-Verbose "Loading class: $($class.Name)"
        . $class.FullName
    }

    # Load Private functions
    $privateFunctions = Get-ChildItem -Path "$ModuleRoot\Private\*.ps1" -ErrorAction SilentlyContinue
    foreach ($function in $privateFunctions) {
        Write-Verbose "Loading private function: $($function.Name)"
        . $function.FullName
    }

    # Load Public functions
    $publicFunctions = Get-ChildItem -Path "$ModuleRoot\Public\*.ps1" -ErrorAction SilentlyContinue
    foreach ($function in $publicFunctions) {
        Write-Verbose "Loading public function: $($function.Name)"
        . $function.FullName
    }

    # Load Data files
    $script:ModuleConfiguration = Import-PowerShellDataFile -Path "$ModuleRoot\Data\DefaultConfiguration.psd1" -ErrorAction SilentlyContinue

    Write-Verbose "Module loaded successfully. Public functions: $($publicFunctions.Count), Private functions: $($privateFunctions.Count)"
}
catch {
    Write-Error "Failed to load module components: $($_.Exception.Message)"
    throw
}

# Module cleanup on removal
$ExecutionContext.SessionState.Module.OnRemove = {
    Write-Verbose "Cleaning up module: $($MyInvocation.MyCommand.Module.Name)"
    # Clean up module variables and resources
    Remove-Variable -Name ModuleConfiguration -Scope Script -ErrorAction SilentlyContinue
}
```

## Function Development

### Public Function Template

Generate public functions following enterprise standards:

```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description using approved PowerShell verb-noun pattern

    .DESCRIPTION
        Comprehensive description including business value, functionality,
        dependencies, and performance characteristics

    .PARAMETER ParameterName
        [Type] (Mandatory: Yes/No, Pipeline: ByValue/ByPropertyName)
        Detailed parameter description with validation rules and business context

    .EXAMPLE
        PS> Verb-Noun -ParameterName "Value"

        DESCRIPTION: What this example demonstrates
        OUTPUT: Expected output description
        USE CASE: Business scenario

    .NOTES
        Author: Jeffrey Stuhr
        Version: 1.0.0
        Last Updated: $(Get-Date -Format 'yyyy-MM-dd')

        TROUBLESHOOTING:
        - Common issues: .\Troubleshooting\Common\Function-Issues.md
        - Performance: .\Troubleshooting\Performance\Optimization.md
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([ExpectedOutputType])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )

    begin {
        $correlationId = [System.Guid]::NewGuid()
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name) - CorrelationId: $correlationId"

        # Initialize collections and validation
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($ParameterName, "Action Description")) {
                # Core function logic with proper error handling
                # Include correlation ID in all operations
            }
        }
        catch {
            Write-Error "Failed to process $ParameterName : $($_.Exception.Message)" -ErrorAction Stop
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand.Name) - CorrelationId: $correlationId"
    }
}
```

### Class Development

Create PowerShell classes with proper validation and methods:

```powershell
# Classes/ModuleConfiguration.ps1
class ModuleConfiguration {
    [ValidateNotNullOrEmpty()]
    [string]$Environment

    [ValidateRange(1, 5)]
    [int]$LogLevel = 3

    [hashtable]$CustomSettings = @{}

    # Constructor with validation
    ModuleConfiguration([string]$Environment) {
        if ([string]::IsNullOrWhiteSpace($Environment)) {
            throw [ArgumentNullException]::new('Environment')
        }
        $this.Environment = $Environment
    }

    # Business logic methods
    [bool] Validate() {
        # Implement validation logic
        return $true
    }

    [hashtable] ToHashtable() {
        return @{
            Environment = $this.Environment
            LogLevel = $this.LogLevel
            CustomSettings = $this.CustomSettings
        }
    }
}
```

## Security Implementation

### Input Validation and Sanitization

Implement comprehensive input validation:

```powershell
function Protect-UserInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString,
        [ValidateSet('ComputerName', 'FileName', 'UserName', 'General')]
        [string]$InputType = 'General'
    )

    # Length validation
    if ($InputString.Length -gt 1000) {
        throw [ValidationException]::new("Input exceeds maximum length", "InputString", $InputString)
    }

    # Type-specific validation
    switch ($InputType) {
        'ComputerName' {
            if ($InputString -notmatch '^[a-zA-Z0-9\-\.]+$') {
                throw [ValidationException]::new("Invalid computer name format", "InputString", $InputString)
            }
        }
        'FileName' {
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            foreach ($char in $invalidChars) {
                if ($InputString.Contains($char)) {
                    throw [ValidationException]::new("Invalid file name character: $char", "InputString", $InputString)
                }
            }
        }
    }

    return $InputString.Trim()
}
```

### Credential Management Integration

Implement secure credential handling:

```powershell
function Get-ModuleCredential {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string]$VaultName = 'DefaultVault'
    )

    try {
        # Use SecretManagement for secure credential storage
        $credential = Get-Secret -Name $Name -Vault $VaultName -AsPlainText:$false -ErrorAction Stop
        return $credential
    }
    catch {
        Write-Warning "Credential not found in vault, prompting user"
        return Get-Credential -Message "Enter credentials for: $Name"
    }
}
```

## Testing Framework Integration

### Pester Test Structure

Generate comprehensive test suites targeting **Pester 6.1+**:

```powershell
# Tests/Unit/Public/Verb-Noun.Tests.ps1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }

BeforeAll {
    # Pester 6 discovers and runs one file at a time - each file must be self-contained
    $ModulePath = Join-Path $PSScriptRoot '..\..\..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force
}

Describe "Verb-Noun" -Tag "Unit", "Public" {
    Context "Parameter Validation" {
        # -ForEach data is injected as variables - no param() block needed.
        # Never name a key 'Input' - it collides with the automatic variable.
        It "Should accept valid input: <TestValue>" -ForEach @(
            @{ TestValue = 'ValidValue1' }
            @{ TestValue = 'ValidValue2' }
        ) {
            # There is no Should-NotThrow - just call it; a throw fails the test
            Verb-Noun -ParameterName $TestValue
        }

        It "Should reject invalid input" {
            { Verb-Noun -ParameterName $null } | Should-Throw
        }
    }

    Context "Functionality" {
        # Only one BeforeEach per block - Pester 6 throws on duplicates
        BeforeEach {
            Mock External-Dependency { "MockedResult" }
        }

        It "Should return expected result" {
            Verb-Noun -ParameterName "TestValue" | Should-NotBeNull
        }

        It "Should call the dependency once" {
            Verb-Noun -ParameterName "TestValue"
            Should-Invoke External-Dependency -Times 1 -Exactly
        }
    }

    Context "Error Handling" {
        It "Should handle errors gracefully" {
            Mock External-Dependency { throw "Test Error" }
            { Verb-Noun -ParameterName "TestValue" } |
                Should-Throw -ExceptionMessage "*Test Error*"
        }
    }
}
```

Key Pester 6 points: `Should-*` assertions replace `Should -Be` for new tests,
`Assert-MockCalled` was removed in favour of `Should-Invoke`, duplicate setup blocks throw, and
every file must import its own dependencies. See
[Pester instructions](./pester.instructions.md) and the
[migration guide](./pester-supporting-docs/v6-migration.md).

## Performance Optimization

### Efficient Resource Management

Implement performance best practices:

```powershell
# Memory-efficient processing
function Process-LargeDataSet {
    param(
        [Parameter(ValueFromPipeline = $true)]
        [object[]]$InputObject
    )

    begin {
        # Initialize StringBuilder for efficient string operations
        $sb = [System.Text.StringBuilder]::new()
        $results = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            # Process items in pipeline for memory efficiency
            $processedItem = Process-Item $item
            $results.Add($processedItem)
        }
    }

    end {
        # Return results and cleanup
        return $results.ToArray()
    }
}
```

### Caching Implementation

Add intelligent caching for improved performance:

```powershell
# Module-level caching
$script:ModuleCache = @{}

function Get-CachedResult {
    param([string]$Key, [ScriptBlock]$Operation, [int]$ExpirationMinutes = 15)

    $cacheEntry = $script:ModuleCache[$Key]
    if ($cacheEntry -and $cacheEntry.ExpirationTime -gt (Get-Date)) {
        return $cacheEntry.Value
    }

    # Execute operation and cache result
    $result = & $Operation
    $script:ModuleCache[$Key] = @{
        Value = $result
        ExpirationTime = (Get-Date).AddMinutes($ExpirationMinutes)
    }

    return $result
}
```

## Documentation and Troubleshooting

### README Generation

Create comprehensive README following enterprise standards:

```markdown
# ModuleName

## 📖 Overview
Clear business value and technical summary

## 🚀 Quick Start
Copy-paste ready examples for immediate use

## 📋 Prerequisites
System requirements, dependencies, and permissions

## 🔧 Installation
Step-by-step installation instructions

## 💡 Usage
Basic and advanced usage examples

## 🔍 Troubleshooting
Reference to ./Troubleshooting/ folder organization

## 📚 References
Links to additional documentation and resources
```

### Troubleshooting Documentation Structure

Organize troubleshooting documentation in standardized folders:

```text
Troubleshooting/
├── Common/
│   ├── Installation-Issues.md
│   ├── Function-Errors.md
│   └── Configuration-Problems.md
├── Security/
│   ├── Credential-Management.md
│   └── Permission-Issues.md
├── Performance/
│   ├── Memory-Usage.md
│   └── Slow-Execution.md
└── Integration/
    ├── API-Connection-Issues.md
    └── External-Dependencies.md
```

## Quality Assurance Requirements

### Pre-Release Checklist

Ensure module meets all quality standards:

- [ ] All public functions have a PlatyPS Markdown file under `docs/` with no `{{ Fill in`
      placeholders remaining; all private functions have comprehensive comment-based help
- [ ] All public functions carry `.EXTERNALHELP ModuleName-Help.xml`
- [ ] MAML built to `en-US/ModuleName-Help.xml` and `Get-Help` verified against the packaged module
- [ ] Pester tests achieve minimum 80% code coverage
- [ ] PSScriptAnalyzer validation passes with no errors
- [ ] Security validation completed (no credential leaks)
- [ ] Performance benchmarks established
- [ ] Cross-platform compatibility tested (if applicable)
- [ ] Documentation complete and accurate
- [ ] Troubleshooting guides organized in proper folder structure

### PowerShell Gallery Preparation

Prepare module for publication:

- [ ] Module manifest includes all required metadata
- [ ] License file included and referenced
- [ ] README provides clear installation and usage instructions
- [ ] Release notes document changes and improvements
- [ ] Version follows semantic versioning principles
- [ ] Dependencies clearly documented and available

Generate comprehensive PowerShell modules that follow all enterprise standards, implement proper security controls,
include comprehensive testing, and provide excellent documentation with organized troubleshooting resources in the
`./Troubleshooting/` folder structure.
