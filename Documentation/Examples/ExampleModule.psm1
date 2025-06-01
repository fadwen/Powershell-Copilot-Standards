<#
.SYNOPSIS
    Enterprise PowerShell module for user management and system administration

.DESCRIPTION
    This module provides enterprise-grade PowerShell functions for user data processing,
    security auditing, and system compliance validation. All functions follow established
    PowerShell community standards and enterprise security practices.

.NOTES
    Author: Jeffrey Stuhr
    Blog: https://www.techbyjeff.net
    LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/

    Quality Standards: https://github.com/EntraVantage/PowerShell-Copilot-Standards
#>

# Module initialization
Write-Verbose "Loading Enterprise PowerShell Module: $($MyInvocation.MyCommand.Name)"

# Expert feedback: Get module version from manifest if needed (use $MyInvocation, not hardcoded strings)
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Verbose "PowerShell 7+ detected - enhanced features available"
}

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

#region Module Aliases
# Set up module aliases (defined in manifest)
if (Get-Command Set-Alias -ErrorAction SilentlyContinue) {
    try {
        Set-Alias -Name 'gud' -Value 'Get-UserData' -Scope Global
        Set-Alias -Name 'tscomp' -Value 'Test-SystemCompliance' -Scope Global
        Write-Verbose "Module aliases configured successfully"
    }
    catch {
        Write-Warning "Failed to configure module aliases: $($_.Exception.Message)"
    }
}
#endregion

# Expert feedback: No unnecessary Export-ModuleMember when using proper manifest
# Expert feedback: No superfluous OnRemove actions for cleanup
# Expert feedback: No Remove-Variable for module scope variables (unnecessary)

Write-Verbose "Enterprise PowerShell Module loaded successfully - Functions available via manifest exports"