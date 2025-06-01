@{
    # Module Information
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'  # Single source of truth for version (not duplicated in .psm1)
    GUID = '12345678-1234-1234-1234-123456789012'  # Generate unique GUID

    # Author Information
    Author = 'Jeffrey Stuhr'
    CompanyName = 'Your Organization'
    Copyright = '(c) 2025 Your Organization. All rights reserved.'
    Description = 'Enterprise PowerShell module providing [specific business functionality] with comprehensive security and compliance features.'

    # PowerShell Requirements
    PowerShellVersion = '5.1'  # Minimum supported version
    CompatiblePSEditions = @('Desktop', 'Core')  # Support both Windows PowerShell and PowerShell Core

    # Architecture Requirements (if needed)
    # ProcessorArchitecture = 'None'  # None, X86, Amd64, IA64

    # Required Assemblies
    # RequiredAssemblies = @()

    # Required Modules (dependencies)
    RequiredModules = @(
        # Add only necessary dependencies
        # @{ ModuleName = 'PSFramework'; ModuleVersion = '1.7.270' }
    )

    # Scripts to run before importing module
    # ScriptsToProcess = @()

    # Type files to load
    # TypesToProcess = @()

    # Format files to load
    # FormatsToProcess = @()

    # Assemblies to load
    # NestedModules = @()

    # Expert feedback: With proper manifest, no need for Export-ModuleMember in .psm1
    # These declarations provide the single source of truth for exports

    # Functions to export - be explicit about what you're exposing
    FunctionsToExport = @(
        'Get-ExampleData',
        'Set-ExampleData',
        'New-ExampleResource',
        'Remove-ExampleResource'
        # Add all public functions here - this eliminates need for Export-ModuleMember
    )

    # Cmdlets to export (usually empty for pure PowerShell modules)
    CmdletsToExport = @()

    # Variables to export (usually empty for security)
    VariablesToExport = @()

    # Aliases to export (use sparingly)
    AliasesToExport = @()

    # DSC Resources to export
    # DscResourcesToExport = @()

    # Module list - modules packaged with this module
    # ModuleList = @()

    # File list - all files packaged with this module
    # FileList = @()

    # Private data for module metadata
    PrivateData = @{
        PSData = @{
            # Module metadata for PowerShell Gallery
            Tags = @('Enterprise', 'PowerShell', 'Automation', 'Security')
            LicenseUri = 'https://github.com/YourOrg/ModuleName/blob/main/LICENSE'
            ProjectUri = 'https://github.com/YourOrg/ModuleName'
            IconUri = 'https://github.com/YourOrg/ModuleName/blob/main/icon.png'
            ReleaseNotes = 'See CHANGELOG.md for detailed release notes'

            # External module dependencies (not available in PowerShell Gallery)
            # ExternalModuleDependencies = @()

            # Prerelease version suffix
            # Prerelease = 'alpha'

            # Minimum PowerShell version required
            # RequireLicenseAcceptance = $false
        }

        # Enterprise-specific metadata
        Enterprise = @{
            SupportContact = 'it-support@yourorg.com'
            DocumentationUri = 'https://docs.yourorg.com/powershell/modulename'
            TroubleshootingUri = 'https://docs.yourorg.com/powershell/modulename/troubleshooting'
            SecurityContact = 'security@yourorg.com'
            ComplianceFrameworks = @('SOX', 'GDPR', 'HIPAA')
        }
    }

    # Help Info URI for updatable help
    # HelpInfoURI = 'https://docs.yourorg.com/powershell/modulename/help'

    # Default command prefix (use sparingly to avoid conflicts)
    # DefaultCommandPrefix = ''
}