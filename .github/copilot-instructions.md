# PowerShell Development Standards for GitHub Copilot

## 🚀 Core Development Principles

### PowerShell Community Standards Integration
All code generation must comply with established PowerShell community best practices and style guidelines:

#### Best Practices Enforcement
- **Tool vs Controller Design**: Create reusable functions (tools) vs one-time automation scripts (controllers)
- **Modular Architecture**: Functions accept input via parameters, output to pipeline for maximum reusability
- **Error Handling Standards**: Use `-ErrorAction Stop`, implement try/catch with correlation IDs, avoid error flags
- **Performance Optimization**: Test when it matters, balance readability vs speed, use language features over cmdlets
- **Security by Design**: Always use PSCredential, implement SecureString handling, validate all inputs

#### Style Guide Compliance
- **Code Layout**: One True Brace Style (opening brace at end of line), 4-space indentation, 115-character line limit
- **Function Structure**: Advanced functions with CmdletBinding, comprehensive parameter validation, proper comment-based help
- **Naming Conventions**: Approved PowerShell verbs only (use `Get-Verb`), full command names, explicit parameter names, PascalCase
- **Documentation Standards**: Complete comment-based help with business value, examples, and troubleshooting references

#### Anti-Patterns to Avoid
- **Performance**: Array appending in loops, excessive string concatenation, inefficient pipeline usage
- **Style**: Backticks for line continuation (use splatting), Write-Host (use Write-Output/Verbose), aliases in scripts
- **Security**: Hardcoded credentials, unsafe input handling, missing validation attributes
- **Error Handling**: Using `$?` for error detection, testing null variables as error conditions

### Script Development Guidelines
- **Approved Verbs Only**: Use Microsoft's approved PowerShell verbs (`Get-Verb`) for all function and cmdlet names
- **Version Compatibility**: Maintain compatibility with Windows PowerShell 5.1 unless specific PowerShell 7+ features are required
- **Version Annotations**: Document any PowerShell 7+ specific features with `#requires -version 7.0` at script header
- **Output Standards**: Avoid `Write-Host` except when colored console output is explicitly required
  - Use `Write-Verbose`, `Write-Debug`, `Write-Information`, `Write-Warning`, or `Write-Error` instead
  - Leverage pipeline output for data flow
- **Pipeline Efficiency**: Always design functions to work efficiently in the pipeline

### Function Structure Requirements
```powershell
function Verb-Noun {
    <#
    .SYNOPSIS
        Brief description using approved verb-noun pattern

    .DESCRIPTION
        Detailed explanation including:
        - Business value and purpose
        - Key functionality and features
        - Dependencies and requirements
        - Performance characteristics

    .PARAMETER ParameterName
        [Type] (Mandatory: Yes/No, Pipeline: ByValue/ByPropertyName)

        Detailed parameter description with:
        - Validation rules and constraints
        - Business context and usage
        - Examples of valid values

    .EXAMPLE
        PS> Verb-Noun -ParameterName "Value"

        DESCRIPTION: What this example demonstrates
        OUTPUT: Expected output description
        USE CASE: Business scenario where this is useful

    .NOTES
        Author: Jeffrey Stuhr
        Blog: https://www.techbyjeff.net
        LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/
        Last Updated: $(Get-Date -Format 'yyyy-MM-dd')
        Version: 1.0.0

        TROUBLESHOOTING:
        - For common issues: .\Troubleshooting\Common\Function-Name-Issues.md
        - For performance: .\Troubleshooting\Performance\Optimization-Guide.md
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([ExpectedOutputType])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ParameterName
    )

    begin {
        # Initialize with correlation ID for tracing
        $correlationId = [System.Guid]::NewGuid()
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name) - CorrelationId: $correlationId"
    }

    process {
        try {
            # Core logic with proper error handling
            if ($PSCmdlet.ShouldProcess($ParameterName, "Action Description")) {
                # Implementation here - return raw data for tools, formatted data for controllers
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

## 🗂️ Mandatory File Organization

All PowerShell projects must follow this standardized structure:

```
ProjectRoot/
├── Public/                     # Exported functions (tools for reuse)
│   └── Verb-Noun.ps1
├── Private/                    # Internal functions
│   └── Internal-Function.ps1
├── Classes/                    # PowerShell classes
│   └── CustomClass.ps1
├── Tests/                      # Pester test suite
│   ├── Unit/
│   ├── Integration/
│   └── Performance/
├── Troubleshooting/           # Organized troubleshooting docs
│   ├── Common/
│   ├── Security/
│   ├── Performance/
│   └── Integration/
├── Documentation/             # Project documentation
│   ├── PowerShell-Best-Practices.md
│   └── PowerShell-Style-Guide.md
├── Configuration/             # Environment configs
└── README.md                  # Main documentation
```

**Critical**: All troubleshooting documentation must be organized in the `Troubleshooting/` folder with appropriate subfolders for consistent reference.

## 🔐 Security Requirements

### Input Validation (Always Required)
```powershell
# Validate all user inputs with type-specific patterns
[Parameter(Mandatory = $true)]
[ValidateNotNullOrEmpty()]
[ValidatePattern('^[a-zA-Z0-9\-\.]+$')]  # Adjust pattern as needed
[string]$InputParameter

# Sanitize file paths to prevent traversal attacks
$safePath = Resolve-Path -Path $InputPath -ErrorAction Stop
if ($safePath.Path.Contains('..')) {
    throw "Invalid path: Path traversal not allowed"
}
```

### Credential Management
```powershell
# Use SecretManagement for credentials - never hardcode
#requires -Module Microsoft.PowerShell.SecretManagement

$credential = Get-Secret -Name 'ServiceAccount' -AsPlainText:$false
# Always use secure credential handling per community standards
```

### Security Logging
```powershell
# Log security-relevant activities with correlation IDs
Write-Warning "Security event: $SecurityEventDescription - User: $env:USERNAME - Time: $(Get-Date)"
```

## 🧪 Testing Requirements

### Minimum Testing Standards
- **Unit Tests**: Required for all public functions (minimum 80% coverage)
- **Integration Tests**: Required for external dependencies
- **Performance Tests**: Required for functions processing >100 items
- **Security Tests**: Required for credential handling and input validation

### Pester Test Template
```powershell
#Requires -Module Pester

Describe "Verb-Noun" -Tag "Unit" {
    BeforeAll {
        # Import module and set up mocks
        Import-Module $PSScriptRoot\..\ModuleName.psd1 -Force

        # Mock external dependencies following community patterns
        Mock Write-Verbose { }
        Mock External-Command { return $MockResult }
    }

    Context "Valid Input" {
        It "Should return expected result for <TestCase>" -TestCases @(
            @{ Input = 'ValidValue1'; Expected = 'ExpectedResult1' }
            @{ Input = 'ValidValue2'; Expected = 'ExpectedResult2' }
        ) {
            param($Input, $Expected)

            $result = Verb-Noun -ParameterName $Input
            $result | Should -Be $Expected
        }
    }

    Context "Error Handling" {
        It "Should throw on invalid input" {
            { Verb-Noun -ParameterName $null } | Should -Throw
        }
    }
}
```

## ⚠️ Error Handling Standards

### Comprehensive Error Handling Pattern
```powershell
# Set appropriate error action preference
$ErrorActionPreference = 'Stop'

try {
    # Core operation with correlation tracking
    $correlationId = [System.Guid]::NewGuid()
    Write-Verbose "Operation started - CorrelationId: $correlationId"

    # Main logic here
    $result = Invoke-Operation -CorrelationId $correlationId

    Write-Verbose "Operation completed successfully - CorrelationId: $correlationId"
    return $result
}
catch {
    # Structured error logging following community standards
    $errorDetails = @{
        CorrelationId = $correlationId
        Function = $MyInvocation.MyCommand.Name
        ErrorMessage = $_.Exception.Message
        StackTrace = $_.ScriptStackTrace
        Timestamp = Get-Date
    }

    Write-Error "Operation failed: $($_.Exception.Message) - CorrelationId: $correlationId"

    # Log to troubleshooting system
    $errorDetails | ConvertTo-Json | Out-File ".\Troubleshooting\Logs\error-$correlationId.json"

    throw
}
finally {
    # Cleanup resources following community disposal patterns
    if ($resource -and $resource -is [System.IDisposable]) {
        $resource.Dispose()
    }
}
```

## 📊 Performance Guidelines

### Memory Management (Community Standards)
```powershell
# Use StringBuilder for string concatenation (avoid performance anti-pattern)
$sb = [System.Text.StringBuilder]::new()
foreach ($item in $collection) {
    [void]$sb.AppendLine($item)
}
$result = $sb.ToString()

# Properly dispose of COM objects
try {
    $comObject = New-Object -ComObject Excel.Application
    # Use COM object
}
finally {
    if ($comObject) {
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($comObject) | Out-Null
        [System.GC]::Collect()
    }
}

# Avoid array appending in loops (performance anti-pattern)
# Instead of: $results += $newItem
# Use pipeline output:
$results = foreach ($item in $collection) {
    Process-Item $item  # Output directly to pipeline
}
```

### Pipeline Optimization (Community Best Practice)
```powershell
# Prefer pipeline operations over foreach loops for large datasets
$results = $largeCollection |
    Where-Object { $_.Status -eq 'Active' } |
    ForEach-Object { Process-Item $_ } |
    Sort-Object Name

# Use language features over cmdlets for performance
# Preferred: Where Status -eq Running
# Over: Where-Object { $_.Status -eq 'Running' }
```

## 🏗️ Module Development Standards

### Module Manifest Requirements
```powershell
# ModuleName.psd1
@{
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'  # Semantic versioning
    GUID = 'Generate-New-Guid'
    Author = 'Jeffrey Stuhr'
    Description = 'Clear description of module purpose and business value'

    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    FunctionsToExport = @('Get-Something', 'Set-Something')  # Explicit exports only
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    RequiredModules = @(
        @{ ModuleName = 'PSFramework'; ModuleVersion = '1.7.270' }
    )

    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'Enterprise', 'Automation')
            ProjectUri = 'https://github.com/organization/module'
            LicenseUri = 'https://github.com/organization/module/blob/main/LICENSE'
        }
    }
}
```

### Root Module Pattern (Community Standard)
```powershell
# ModuleName.psm1
#Requires -Version 5.1

# Import components in order following community practices
$components = @('Classes', 'Private', 'Public')
foreach ($component in $components) {
    $path = Join-Path $PSScriptRoot $component
    if (Test-Path $path) {
        Get-ChildItem "$path\*.ps1" | ForEach-Object {
            Write-Verbose "Loading $($_.Name)"
            . $_.FullName
        }
    }
}

# Module cleanup following community disposal patterns
$ExecutionContext.SessionState.Module.OnRemove = {
    Write-Verbose "Cleaning up module: $($MyInvocation.MyCommand.Module.Name)"
    # Cleanup resources
}
```

## 📝 Documentation Standards

### README Structure (Required)
```markdown
# Project Title
## 📖 Overview (Business value and purpose)
## 🚀 Quick Start (Copy-paste ready examples)
## 📋 Prerequisites (System requirements and dependencies)
## 🔧 Installation (Step-by-step setup)
## 💡 Usage (Basic and advanced examples)
## 🔍 Troubleshooting (Reference to ./Troubleshooting/ folder)
## 📚 References (Links to additional documentation)
```

### Troubleshooting Documentation
- **Location**: Always in `.\Troubleshooting\` folder
- **Organization**: By category (Common, Security, Performance, Integration)
- **Format**: Markdown with clear headings and actionable solutions
- **Linking**: Reference from code comments and README

## 🔄 CI/CD Integration

### Quality Gates (Required)
```powershell
# Pre-commit validation following community standards
$qualityChecks = @{
    PSScriptAnalyzer = Invoke-ScriptAnalyzer -Path . -Recurse
    PesterTests = Invoke-Pester -PassThru
    SecurityScan = Test-ScriptSecurity -Path .
    CommunityStandards = Test-PowerShellCommunityCompliance -Path .
}

# Fail if quality gates not met
if ($qualityChecks.PSScriptAnalyzer.Count -gt 0) {
    throw "PSScriptAnalyzer issues found"
}
if ($qualityChecks.PesterTests.FailedCount -gt 0) {
    throw "Test failures detected"
}
```

## 🎯 Community Standards Integration

### Automatic Validation
All generated code must automatically comply with:
- [ ] **Tool Design**: Functions are reusable with parameter input and pipeline output
- [ ] **Approved Verbs**: Only Microsoft-approved verbs from Get-Verb
- [ ] **Style Compliance**: One True Brace Style, 4-space indentation, 115-character lines
- [ ] **Error Handling**: -ErrorAction Stop usage, proper try/catch with correlation IDs
- [ ] **Performance**: No array appending, efficient string operations, pipeline optimization
- [ ] **Security**: PSCredential usage, input validation, no hardcoded secrets
- [ ] **Documentation**: Complete comment-based help with business value
- [ ] **Naming**: Full command names, PascalCase, explicit parameters

### Quality Standards Reference
For detailed community standards implementation:
- **Best Practices**: See `.github/instructions/community-standards.instructions.md`
- **Style Enforcement**: See `.github/instructions/style-enforcement.instructions.md`
- **Validation Prompt**: Use `/validate-standards` for quick compliance checking
- **Full Documentation**: Reference `./Documentation/PowerShell-Best-Practices.md`

## 🎯 Code Review Checklist

When generating or reviewing code, ensure:
- [ ] Uses approved PowerShell verbs and follows community naming conventions
- [ ] Implements tool vs controller design pattern appropriately
- [ ] Includes comprehensive comment-based help with business value
- [ ] Implements proper error handling with correlation IDs and community patterns
- [ ] Validates all input parameters with appropriate attributes
- [ ] Includes appropriate Pester tests with community testing patterns
- [ ] Follows security best practices and community security guidelines
- [ ] Organizes troubleshooting docs in `./Troubleshooting/` folder
- [ ] Maintains cross-platform compatibility considerations
- [ ] Uses semantic versioning for modules
- [ ] Implements structured logging for enterprise environments
- [ ] Avoids community-identified anti-patterns and performance issues

## 📚 Quick Reference Links

- **Community Standards**: Reference `.github/instructions/community-standards.instructions.md`
- **Style Guide**: Reference `.github/instructions/style-enforcement.instructions.md`
- **Troubleshooting**: Always organized in `./Troubleshooting/` folder structure
- **Testing**: Use Pester 5.x with comprehensive coverage requirements
- **Security**: Implement defense-in-depth with community-approved patterns
- **Performance**: Optimize using community-identified best practices

## 📚 Detailed Guidance
For specialized scenarios, reference these instruction files:
- Security & Compliance: [Security Guidelines](./instructions/securitycompliance-instructions.md)
- Testing Standards: [Testing Framework](./instructions/pester-instructions.md)
- Architecture Design: [Design Patterns](./instructions/architecturedesign-instructions.md)
- Module Development: [Module Standards](./instructions/module-instructions.md)
- CI/CD Integration: [Pipeline Setup](./instructions/cicd-instructions.md)
- Error Handling: [Logging Framework](./instructions/errorsandlogs-instructions.md)
- Documentation: [README Standards](./instructions/readme-instructions.md)
- Code Analysis: [Quality Standards](./instructions/analyze-instructions.md)
- Comment Standards: [Help Documentation](./instructions/comments-instructions.md)
- Community Standards: [Best Practices Integration](./instructions/community-standards.instructions.md)
- Style Enforcement: [Style Guide Compliance](./instructions/style-enforcement.instructions.md)

---

*This file provides core standards automatically applied by GitHub Copilot, integrating established PowerShell community best practices and style guidelines. For detailed guidance on specific topics, reference the individual prompt files and troubleshooting documentation.*