@{
    # Module Information
    RootModule = 'ExampleModule.psm1'
    ModuleVersion = '1.2.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author Information
    Author = 'Jeffrey Stuhr'
    CompanyName = 'EntraVantage'
    Copyright = '(c) 2025 EntraVantage. All rights reserved.'
    Description = 'Example enterprise PowerShell module demonstrating best practices for data processing, user management, and system administration with comprehensive security and compliance features.'

    # PowerShell Requirements
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    # Required Modules (enterprise dependencies)
    RequiredModules = @(
        @{ ModuleName = 'ActiveDirectory'; ModuleVersion = '1.0.0.0' }
        @{ ModuleName = 'PSFramework'; ModuleVersion = '1.7.270' }
    )

    # Expert feedback: With proper manifest, no need for Export-ModuleMember in .psm1
    # These declarations provide the single source of truth for exports

    # Functions to export - explicit list eliminates need for Export-ModuleMember
    FunctionsToExport = @(
        'Get-UserData',
        'Set-UserPermissions',
        'New-ServiceAccount',
        'Remove-StaleAccounts',
        'Test-SystemCompliance',
        'Invoke-SecurityAudit',
        'Get-PerformanceMetrics',
        'Set-ConfigurationBaseline'
    )

    # Cmdlets to export (usually empty for pure PowerShell modules)
    CmdletsToExport = @()

    # Variables to export (keep empty for security)
    VariablesToExport = @()

    # Aliases to export (use sparingly in enterprise environments)
    AliasesToExport = @(
        'gud',      # Get-UserData
        'tscomp'    # Test-SystemCompliance
    )

    # Private data for module metadata
    PrivateData = @{
        PSData = @{
            # Module metadata for PowerShell Gallery
            Tags = @('Enterprise', 'PowerShell', 'Security', 'Compliance', 'UserManagement', 'Automation')
            LicenseUri = 'https://github.com/EntraVantage/ExampleModule/blob/main/LICENSE'
            ProjectUri = 'https://github.com/EntraVantage/ExampleModule'
            ReleaseNotes = @'
## v1.2.0 Release Notes

### New Features
- Added Test-SystemCompliance function for SOX compliance validation
- Enhanced Get-UserData with group membership filtering
- New Invoke-SecurityAudit function for comprehensive security assessment

### Improvements
- Updated error handling patterns based on expert PowerShell feedback
- Improved parameter validation for enterprise functions
- Enhanced correlation ID tracking throughout all functions

### Security Enhancements
- Implemented modern credential handling patterns
- Added comprehensive input validation
- Enhanced audit logging capabilities

### Breaking Changes
- Removed basic authentication support (security improvement)
- Updated parameter validation for downstream function safety

For detailed changes, see CHANGELOG.md
'@

            # Minimum PowerShell version required
            RequireLicenseAcceptance = $false
        }

        # Enterprise-specific metadata
        Enterprise = @{
            SupportContact = 'powershell-support@entravantage.com'
            DocumentationUri = 'https://docs.entravantage.com/powershell/examplemodule'
            TroubleshootingUri = 'https://docs.entravantage.com/powershell/examplemodule/troubleshooting'
            SecurityContact = 'security@entravantage.com'
            ComplianceFrameworks = @('SOX', 'GDPR', 'HIPAA', 'PCI-DSS')
            QualityStandards = 'https://github.com/EntraVantage/PowerShell-Copilot-Standards'
        }
    }

    # Help Info URI for updatable help
    HelpInfoURI = 'https://docs.entravantage.com/powershell/examplemodule/help'
}