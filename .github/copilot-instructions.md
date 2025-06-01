# PowerShell Copilot Instructions

## 🎯 Core Principles
You are assisting with enterprise PowerShell development that prioritizes security, maintainability, and performance. Always follow these foundational principles:

1. **Security by Design**: Implement comprehensive input validation and secure credential handling
2. **Correlation Tracking**: Include correlation IDs for audit trails and troubleshooting
3. **Error Resilience**: Implement robust error handling with structured logging
4. **Performance Awareness**: Write efficient code with appropriate optimization
5. **Community Standards**: Follow established PowerShell best practices and style guidelines
6. **Enterprise Integration**: Design for scalability and organizational compliance

## 📋 Community Standards Integration

### PowerShell Community Standards Compliance
All code generation must comply with established PowerShell community best practices and style guidelines, incorporating expert feedback for accuracy:

#### Best Practices Enforcement
- **Tool vs Controller Design**: Create reusable functions (tools) vs one-time automation scripts (controllers)
- **Modular Architecture**: Functions accept input via parameters, output to pipeline for maximum reusability
- **Error Handling Standards**: Use proper `$_` handling in catch blocks, appropriate null checking patterns
- **Performance Optimization**: Context-dependent string operations, test when it matters, use language features over cmdlets
- **Security by Design**: Modern credential handling with `[PSCredential]::new()`, validate all inputs, sanitize data

#### Style Guide Compliance
- **Code Layout**: One True Brace Style (opening brace at end of line), 4-space indentation, 115-character line limit
- **Function Structure**: Advanced functions with CmdletBinding, appropriate parameter validation (no redundant attributes)
- **Naming Conventions**: Approved PowerShell verbs only (use `Get-Verb`), full command names, explicit parameter names, PascalCase
- **Documentation Standards**: Proper comment-based help format with opening `<#`, no maintenance-heavy versioning in NOTES

#### Anti-Patterns to Avoid
- **Error Handling**: Don't use `$Error[0]` in catch blocks (use `$_`), don't force exceptions for simple existence checks
- **Throw Behavior**: Be aware that `throw` statements can be silenced by `-ErrorAction SilentlyContinue` - use `Write-Error -ErrorAction Stop` for proper termination when needed
- **Parameter Usage**: Don't pass parameters to functions without validating they have values, especially when parameters might be empty strings or whitespace
- **Performance**: Don't use StringBuilder for small string operations (< 100 concatenations), don't use array appending in large loops
- **Validation**: Don't add ValidateNotNullOrEmpty to mandatory parameters unless they'll be used in downstream function calls where empty strings matter
- **Output**: Don't use misleading `[OutputType([PSCustomObject])]` declarations
- **Documentation**: Don't use broken comment-based help (missing `<#` opener)

### Script Development Guidelines
- **Approved Verbs Only**: Use Microsoft's approved PowerShell verbs (`Get-Verb`) for ALL function names consistently
- **Version Compatibility**: Maintain compatibility with Windows PowerShell 5.1 unless specific PowerShell 7+ features are required
- **Version Annotations**: Document any PowerShell 7+ specific features with `#requires -version 7.0` at script header
- **Output Standards**: Avoid `Write-Host` except when colored console output is explicitly required
  - Use `Write-Verbose`, `Write-Debug`, `Write-Information`, `Write-Warning`, or `Write-Error` instead
  - Leverage pipeline output for data flow
- **Pipeline Efficiency**: Always design functions to work efficiently in the pipeline

### Modern PowerShell Features
- Use `[PSCredential]::new()` instead of `New-Object` for credential creation
- Leverage PowerShell 5.1+ features when available
- Avoid redundant parameter validation (mandatory parameters are implicitly not null/empty)

## 🛡️ Security Requirements

### Input Validation
```powershell
# Appropriate validation patterns
param(
    [Parameter(Mandatory)]
    [string]$ComputerName,  # Mandatory implies not null/empty

    [Parameter()]
    [ValidateNotNullOrEmpty()]  # Explicit validation for optional params
    [ValidatePattern('^[a-zA-Z0-9\-\.]+$')]
    [string]$OptionalServer
)

# Sanitize file paths to prevent traversal attacks
$safePath = Resolve-Path -Path $InputPath -ErrorAction Stop
if ($safePath.Path.Contains('..')) {
    throw "Invalid path: Path traversal not allowed"
}
```

### Credential Management
```powershell
# Modern credential creation (PowerShell 5+)
$credential = [PSCredential]::new($username, $securePassword)

# Always use secure credential handling per community standards
$secureString = ConvertTo-SecureString $Password -AsPlainText -Force
```

### Security Scanning Patterns
Avoid these patterns in production code:
- Hardcoded passwords or API keys
- Plain text credential storage
- SQL injection vulnerabilities in dynamic queries
- Unvalidated user input in file paths or commands

### Security Logging
```powershell
# Log security-relevant activities with correlation IDs
Write-Warning "Security event: $SecurityEventDescription - User: $env:USERNAME - Time: $(Get-Date)"
```

## 🔧 Function Template

```powershell
function Get-ExampleData {
    <#
    .SYNOPSIS
        Brief description using approved verb-noun pattern

    .DESCRIPTION
        Detailed explanation including:
        - Business value and purpose
        - Key functionality and features
        - Dependencies and requirements
        - Performance characteristics

    .PARAMETER Name
        Description of mandatory parameter (implicitly validated as not null/empty)

    .PARAMETER OptionalPath
        Description of optional parameter with explicit validation

    .EXAMPLE
        PS> Get-ExampleData -Name "Value"

        DESCRIPTION: What this example demonstrates
        OUTPUT: Expected output description
        USE CASE: Business scenario where this is useful

    .NOTES
        Author: Jeffrey Stuhr
        Blog: https://www.techbyjeff.net
        LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/

        TROUBLESHOOTING:
        - For common issues: .\Troubleshooting\Common\Function-Name-Issues.md
        - For performance: .\Troubleshooting\Performance\Optimization-Guide.md
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('ProcessedData')]  # Use descriptive type name, not [PSCustomObject]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]  # Explicit validation even for mandatory params when used in downstream functions
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OptionalPath,

        [Parameter()]
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-EnterpriseLog -Level "INFO" -Message "Starting $($MyInvocation.MyCommand.Name)" -CorrelationId $CorrelationId

        # Load configuration
        $config = Get-EnvironmentConfiguration
    }

    process {
        try {
            # Validate parameters before using in function calls (expert feedback Part 2)
            if (-not $Name.Trim()) {
                Write-Error "Name parameter cannot be empty or whitespace" -ErrorAction Stop
                return
            }

            if ($PSCmdlet.ShouldProcess($Name, "Process Data")) {
                # Modern credential creation if needed
                if ($needsCredential) {
                    $credential = [PSCredential]::new($username, $securePassword)
                }

                # Context-appropriate string operations
                if ($items.Count -lt 100) {
                    # Small operations - += is fine and readable
                    $summary = "Processing: $Name"
                    $summary += " at $(Get-Date)"
                } else {
                    # Large operations - use StringBuilder
                    $sb = [System.Text.StringBuilder]::new()
                    foreach ($item in $items) {
                        [void]$sb.AppendLine("Processing: $item")
                    }
                    $summary = $sb.ToString()
                }

                # Appropriate null checking for optional data
                $optionalData = Get-OptionalData -Name $Name.Trim() -ErrorAction SilentlyContinue
                if ($optionalData) {
                    # Process optional data - null check is valid here
                    Write-Verbose "Found optional data for $Name"
                }

                # Return data with explicit type name for better tooling
                $result = [PSCustomObject]@{
                    PSTypeName = 'ProcessedData'
                    Name = $Name
                    ProcessedAt = Get-Date
                    CorrelationId = $CorrelationId
                    HasOptionalData = [bool]$optionalData
                }

                Write-Output $result
            }
        }
        catch {
            # CORRECT: Use $_ not $Error[0] in catch blocks
            $errorDetails = @{
                Message = $_.Exception.Message
                Category = $_.CategoryInfo.Category
                TargetObject = $_.TargetObject
                CorrelationId = $CorrelationId
                Function = $MyInvocation.MyCommand.Name
                Line = $_.InvocationInfo.ScriptLineNumber
            }

            Write-EnterpriseLog -Level "ERROR" -Message "Processing failed" -Details $errorDetails -CorrelationId $CorrelationId

            # Use Write-Error with -ErrorAction Stop instead of bare throw for proper error action handling
            Write-Error "Failed to process $Name : $($_.Exception.Message)" -ErrorAction Stop
        }
    }

    end {
        Write-EnterpriseLog -Level "INFO" -Message "Completed $($MyInvocation.MyCommand.Name)" -CorrelationId $CorrelationId
    }
}
```

## 🗂️ Mandatory File Organization

All PowerShell projects must follow this standardized structure:

```
ProjectRoot/
├── Public/                     # Exported functions (tools for reuse)
│   └── Get-SomethingData.ps1   # Use approved verbs consistently
├── Private/                    # Internal functions
│   └── Connect-InternalService.ps1
├── Classes/                    # PowerShell classes with explicit type names
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

## 🚀 Performance Guidelines

### Context-Dependent String Operations
```powershell
# For small operations (< 100 concatenations), += is fine and more readable
if ($items.Count -lt 100) {
    $output = "Processing started at: $(Get-Date)"
    foreach ($item in $items) {
        $output += "`nProcessing: $item"
    }
} else {
    # For large operations, use StringBuilder for performance
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("Processing started at: $(Get-Date)")
    foreach ($item in $items) {
        [void]$sb.AppendLine("Processing: $item")
    }
    $output = $sb.ToString()
}
```

### Avoid These Anti-Patterns
```powershell
# ❌ Array appending in loops (creates new array each time)
$results = @()
foreach ($item in $collection) {
    $results += Process-Item $item
}

# ✅ Use ArrayList or generic collections
$results = [System.Collections.ArrayList]::new()
foreach ($item in $collection) {
    [void]$results.Add((Process-Item $item))
}

# ✅ Better: Use pipeline when possible
$results = $collection | ForEach-Object { Process-Item $_ }
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

## ⚠️ Error Handling Standards

### Proper Error Handling Pattern
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
    # CORRECT: Use $_ not $Error[0] in catch blocks
    Write-Error "Operation failed: $($_.Exception.Message) - CorrelationId: $correlationId"

    # Log to troubleshooting system
    $errorDetails = @{
        CorrelationId = $correlationId
        Function = $MyInvocation.MyCommand.Name
        ErrorMessage = $_.Exception.Message  # Use $_ directly
        StackTrace = $_.ScriptStackTrace
        Timestamp = Get-Date
    }
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

### Advanced Error Handling Considerations

#### Throw Behavior with ErrorAction SilentlyContinue
**Important**: Be aware that `throw` statements can be silenced by `-ErrorAction SilentlyContinue`, even though `throw` creates terminating errors:

```powershell
# ⚠️ This throw will be silenced and execution continues
function Test-ErrorHandling {
    param([string]$Value)

    if (-not $Value) {
        throw "Value is required"  # This gets silenced with -ErrorAction SilentlyContinue
    }

    Write-Output "Processing: $Value"
}

# This will NOT stop execution as expected:
Test-ErrorHandling -Value "" -ErrorAction SilentlyContinue
Write-Output "This line will execute unexpectedly"

# ✅ Better approach for validation that should never be silenced:
function Test-ErrorHandling {
    param([string]$Value)

    if (-not $Value) {
        # Use Write-Error with -ErrorAction Stop for proper termination
        Write-Error "Value is required" -ErrorAction Stop
        return  # Explicit return as safety net
    }

    Write-Output "Processing: $Value"
}
```

#### Parameter Validation Before Usage
**Best Practice**: Always validate parameters have values before using them in function calls:

```powershell
# ❌ Potential issue - passing potentially empty/null parameters
function Process-Data {
    param(
        [string]$ServerName,
        [string]$DatabaseName
    )

    # This could fail if parameters are empty
    $connection = Connect-Database -Server $ServerName -Database $DatabaseName
}

# ✅ Proper validation before usage
function Process-Data {
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ServerName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName
    )

    # Additional runtime validation for critical operations
    if (-not $ServerName.Trim()) {
        Write-Error "ServerName cannot be empty or whitespace" -ErrorAction Stop
        return
    }

    if (-not $DatabaseName.Trim()) {
        Write-Error "DatabaseName cannot be empty or whitespace" -ErrorAction Stop
        return
    }

    # Now safe to use in function calls
    $connection = Connect-Database -Server $ServerName.Trim() -Database $DatabaseName.Trim()
}
```

### Appropriate Null Checking vs Exception Handling
```powershell
# VALID: Simple existence check for optional data
$optionalUser = Get-ADUser -Identity $username -ErrorAction SilentlyContinue
if ($optionalUser) {
    # Process user if found
    Write-Verbose "Found user: $($optionalUser.Name)"
} else {
    Write-Verbose "User not found: $username"
}

# ALSO VALID: Exception-based for critical operations
try {
    $criticalUser = Get-ADUser -Identity $username -ErrorAction Stop
    # Process critical user data
} catch {
    Write-Error "Critical user lookup failed: $($_.Exception.Message)"
    throw
}

# Use null checks when you only care about existence
# Use try/catch when you need detailed error information or when failure should halt execution
```

## 🧪 Testing Standards

### Minimum Testing Requirements
- **Unit Tests**: Required for all public functions (minimum 80% coverage)
- **Integration Tests**: Required for external dependencies
- **Performance Tests**: Required for functions processing >100 items
- **Security Tests**: Required for credential handling and input validation

### Pester Test Template
```powershell
#Requires -Module Pester

Describe "Get-ExampleData" -Tag "Unit" {
    BeforeAll {
        # Import module and set up mocks
        Import-Module $PSScriptRoot\..\ModuleName.psd1 -Force

        # Mock external dependencies following community patterns
        Mock Write-Verbose { }
        Mock Get-OptionalData { return $MockResult }
    }

    Context "Valid Input" {
        It "Should return expected result for <TestCase>" -TestCases @(
            @{ Input = 'ValidValue1'; Expected = 'ExpectedResult1' }
            @{ Input = 'ValidValue2'; Expected = 'ExpectedResult2' }
        ) {
            param($Input, $Expected)

            $result = Get-ExampleData -Name $Input
            $result | Should -BeOfType [PSCustomObject]
            $result.PSTypeName | Should -Be 'ProcessedData'
            $result.Name | Should -Be $Expected
        }
    }

    Context "Error Handling" {
        It "Should handle errors correctly using proper error patterns" {
            Mock Get-OptionalData { throw "Test error" }

            { Get-ExampleData -Name "TestValue" } | Should -Throw "*Test error*"
        }
    }
}
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
## 🎯 Community Standards Integration

### Automatic Validation
All generated code must automatically comply with:
- [ ] **Error Handling**: Use `$_` in catch blocks, appropriate null checking patterns, be aware of `throw` behavior with ErrorAction
- [ ] **Parameter Validation**: Validate parameters before using in function calls, especially for empty/whitespace values
- [ ] **Approved Verbs**: Only Microsoft-approved verbs from Get-Verb (consistently in ALL examples)
- [ ] **String Operations**: Context-appropriate choice between += and StringBuilder
- [ ] **Modern PowerShell**: Use `[PSCredential]::new()` instead of New-Object
- [ ] **Output Types**: Use descriptive type names or custom classes, not misleading [PSCustomObject]
- [ ] **Documentation**: Proper comment-based help format with opening `<#` marker
- [ ] **Performance**: No array appending in large loops, efficient pipeline operations
- [ ] **Error Termination**: Use `Write-Error -ErrorAction Stop` instead of bare `throw` when ErrorAction compliance is needed

## 🔍 Quality Standards

### Code Review Checklist
- ✅ Uses approved PowerShell verbs and follows community naming conventions consistently
- ✅ Implements proper error handling with `$_` usage and appropriate null checking
- ✅ Includes comprehensive comment-based help with proper `<#` opening format
- ✅ Uses context-appropriate string operations and performance patterns
- ✅ Follows modern PowerShell practices (PSCredential constructor, appropriate validation)
- ✅ Includes appropriate Pester tests with community testing patterns
- ✅ Uses descriptive output types instead of misleading [PSCustomObject] declarations
- ✅ Organizes troubleshooting docs in `./Troubleshooting/` folder
- ✅ Maintains cross-platform compatibility considerations
- ✅ Uses semantic versioning for modules
- ✅ Implements structured logging for enterprise environments
- ✅ Avoids community-identified anti-patterns and outdated practices
- ✅ Implements correlation tracking
- ✅ Follows security best practices
- ✅ Includes appropriate performance optimizations
- ✅ Supports enterprise compliance requirements

### Validation Commands
Use these prompts for quality assurance:
- `/validate-standards` - Check against community standards
- `/security-review` - Security and compliance analysis
- `/code-analysis` - Comprehensive quality review
- `/optimize-performance` - Performance optimization review

## 📚 Comprehensive Reference Documentation

### Quick Reference Links
- **Community Standards**: Reference `.github/instructions/community-standards.instructions.md`
- **Style Guide**: Reference `.github/instructions/style-enforcement.instructions.md`
- **Troubleshooting**: Always organized in `./Troubleshooting/` folder structure
- **Testing**: Use Pester 5.x with comprehensive coverage requirements
- **Security**: Implement defense-in-depth with community-approved patterns
- **Performance**: Optimize using community-identified best practices and expert feedback

### Detailed Guidance
For specialized scenarios, reference these instruction files:
- **Security & Compliance**: [Security Guidelines](./instructions/securitycompliance-instructions.md)
- **Testing Standards**: [Testing Framework](./instructions/pester-instructions.md)
- **Architecture Design**: [Design Patterns](./instructions/architecturedesign-instructions.md)
- **Module Development**: [Module Standards](./instructions/module-instructions.md)
- **CI/CD Integration**: [Pipeline Setup](./instructions/cicd-instructions.md)
- **Error Handling**: [Logging Framework](./instructions/errorsandlogs-instructions.md)
- **Documentation**: [README Standards](./instructions/readme-instructions.md)
- **Code Analysis**: [Quality Standards](./instructions/analyze-instructions.md)
- **Comment Standards**: [Help Documentation](./instructions/comments-instructions.md)
- **Community Standards**: [Best Practices Integration](./instructions/community-standards.instructions.md)
- **Style Enforcement**: [Style Guide Compliance](./instructions/style-enforcement.instructions.md)

### Implementation Documentation
- [Implementation Guide](./Documentation/Implementation-Guide.md): Step-by-step setup and adoption
- [PowerShell Best Practices](./Documentation/PowerShell-Best-Practices.md): Comprehensive community standards
- [Enterprise Extensions](./Documentation/Enterprise-Extensions.md): Organizational customizations
- [Troubleshooting Guides](./Troubleshooting/): Organized problem-solving resources

---

*This file provides core standards automatically applied by GitHub Copilot, integrating established PowerShell community best practices with expert feedback corrections. For detailed guidance on specific topics, reference the individual instruction files and comprehensive documentation structure.*