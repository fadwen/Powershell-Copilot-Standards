<#
.SYNOPSIS
    Enterprise PowerShell module for [Business Purpose]

.DESCRIPTION
    This module provides enterprise-grade PowerShell functions for [specific business domain].
    All functions follow established PowerShell community standards and enterprise security practices.

.NOTES
    Author: Jeffrey Stuhr
    Blog: https://www.techbyjeff.net
    LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/
#>

# Module initialization
Write-Verbose "Loading Enterprise PowerShell Module: $($MyInvocation.MyCommand.Name)"

# Get module version from manifest if needed (expert feedback: use $MyInvocation, not hardcoded strings)
# $ModuleVersion = (Get-Module $MyInvocation.MyCommand.ModuleName).Version

#region Private Functions
# Load private functions - these are not exported
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded private function: $($Function.BaseName)"
    }
    catch {
        Write-Warning "Failed to load private function $($Function.BaseName): $($_.Exception.Message)"
    }
}
#endregion

#region Public Functions
# Load public functions - these will be exported via manifest
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded public function: $($Function.BaseName)"
    }
    catch {
        Write-Warning "Failed to load public function $($Function.BaseName): $($_.Exception.Message)"
    }
}
#endregion

#region Classes
# Load PowerShell classes if present
$ClassFiles = Get-ChildItem -Path "$PSScriptRoot\Classes\*.ps1" -ErrorAction SilentlyContinue
foreach ($ClassFile in $ClassFiles) {
    try {
        . $ClassFile.FullName
        Write-Verbose "Loaded class: $($ClassFile.BaseName)"
    }
    catch {
        Write-Warning "Failed to load class $($ClassFile.BaseName): $($_.Exception.Message)"
    }
}
#endregion

#region Module Configuration
# Load default configuration
$DefaultConfigPath = Join-Path $PSScriptRoot "Configuration\DefaultConfiguration.psd1"
if (Test-Path $DefaultConfigPath) {
    try {
        $ModuleConfig = Import-PowerShellDataFile -Path $DefaultConfigPath
        Write-Verbose "Loaded module configuration from: $DefaultConfigPath"

        # Store configuration in module scope for access by functions
        Set-Variable -Name "ModuleConfiguration" -Value $ModuleConfig -Scope Script
    }
    catch {
        Write-Warning "Failed to load module configuration: $($_.Exception.Message)"
    }
}
#endregion

Write-Verbose "Enterprise PowerShell Module loaded successfully"