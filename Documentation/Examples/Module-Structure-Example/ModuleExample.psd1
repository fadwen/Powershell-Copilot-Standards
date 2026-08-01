@{
    # Module Information
    RootModule        = 'ModuleExample.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '8f2b1c9d-4e7a-4b3f-9c21-5d6e8a0f7b34'

    # Author Information
    Author            = 'Jeffrey Stuhr'
    CompanyName       = 'YourOrg'
    Copyright         = '(c) 2026 YourOrg. All rights reserved.'
    Description       = 'Minimal reference module demonstrating the Public/Private/Classes layout and the export boundary described in the PowerShell Copilot Standards.'

    # PowerShell Requirements
    # 7.6 is the current LTS. Use '5.1' with @('Desktop','Core') only when Windows
    # PowerShell support is an explicit requirement.
    PowerShellVersion = '7.6'
    CompatiblePSEditions = @('Core')

    # Only the public surface is exported. Connect-ExampleService stays internal, so
    # it can change without a breaking release.
    FunctionsToExport = @('Get-ExampleData')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags       = @('PowerShell', 'Example', 'Standards', 'Reference')
            ProjectUri = 'https://github.com/fadwen/Powershell-Copilot-Standards'
            LicenseUri = 'https://github.com/fadwen/Powershell-Copilot-Standards/blob/main/LICENSE'
            ReleaseNotes = 'Reference implementation accompanying the PowerShell Copilot Standards.'
        }
    }
}
