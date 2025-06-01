@{
    # Basic Module Information
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'REPLACE-WITH-NEW-GUID'  # Generate with: [System.Guid]::NewGuid()
    Author = 'Your Name'
    CompanyName = 'Your Organization'
    Copyright = '(c) 2024 Your Organization. All rights reserved.'
    Description = 'Brief description of what this module does and its business value'

    # PowerShell Version Requirements
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop', 'Core')

    # Dependencies
    RequiredModules = @(
        @{ ModuleName = 'PSFramework'; ModuleVersion = '1.7.270'; Guid = '8028b914-132b-431f-baa9-94a6b90096a6' }
    )

    # Module Components
    FunctionsToExport = @()  # Will be populated automatically by build process
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    # PowerShell Gallery Metadata
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShell', 'Enterprise', 'Automation', 'Management')
            LicenseUri = 'https://github.com/yourorg/modulename/blob/main/LICENSE'
            ProjectUri = 'https://github.com/yourorg/modulename'
            IconUri = 'https://github.com/yourorg/modulename/raw/main/Assets/icon.png'
            ReleaseNotes = 'Initial release with core functionality'
            RequireLicenseAcceptance = $false
            Prerelease = ''
        }
    }

    # Help Information
    HelpInfoURI = 'https://docs.yourorg.com/powershell/modulename'
    
    # Default Prefix (optional)
    # DefaultCommandPrefix = 'Org'
}