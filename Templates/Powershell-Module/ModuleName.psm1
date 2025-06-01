#Requires -Version 5.1

<#
.SYNOPSIS
    Root module file for ModuleName PowerShell module

.DESCRIPTION
    This module provides enterprise-grade PowerShell functionality
    with comprehensive error handling, security controls, and 
    performance optimization.

.NOTES
    Author: Your Name
    Version: 1.0.0
    Enterprise Standards: Compliant
    
    This module follows enterprise PowerShell development standards
    and integrates with organizational monitoring and security systems.
#>

# Module Variables
$script:ModuleRoot = $PSScriptRoot
$script:ModuleName = 'ModuleName'
$script:ModuleVersion = '1.0.0'

# Module Initialization
Write-Verbose "Initializing module: $script:ModuleName v$script:ModuleVersion"

# Import module components in correct order
try {
    # 1. Load Classes first (dependencies for functions)
    $classPath = Join-Path $script:ModuleRoot 'Classes'
    if (Test-Path $classPath) {
        $classFiles = Get-ChildItem -Path $classPath -Filter '*.ps1' -ErrorAction SilentlyContinue
        foreach ($class in $classFiles) {
            Write-Verbose "Loading class: $($class.Name)"
            . $class.FullName
        }
    }

    # 2. Load Private functions (internal dependencies)
    $privatePath = Join-Path $script:ModuleRoot 'Private'
    if (Test-Path $privatePath) {
        $privateFunctions = Get-ChildItem -Path $privatePath -Filter '*.ps1' -ErrorAction SilentlyContinue
        foreach ($function in $privateFunctions) {
            Write-Verbose "Loading private function: $($function.Name)"
            . $function.FullName
        }
    }

    # 3. Load Public functions (exported functionality)
    $publicPath = Join-Path $script:ModuleRoot 'Public'
    if (Test-Path $publicPath) {
        $publicFunctions = Get-ChildItem -Path $publicPath -Filter '*.ps1' -ErrorAction SilentlyContinue
        foreach ($function in $publicFunctions) {
            Write-Verbose "Loading public function: $($function.Name)"
            . $function.FullName
        }
    }

    # 4. Load Configuration data
    $configPath = Join-Path $script:ModuleRoot 'Configuration\DefaultConfiguration.psd1'
    if (Test-Path $configPath) {
        $script:ModuleConfiguration = Import-PowerShellDataFile -Path $configPath -ErrorAction SilentlyContinue
        Write-Verbose "Loaded module configuration"
    }

    # Module load success
    $loadSummary = @{
        ModuleName = $script:ModuleName
        Version = $script:ModuleVersion
        ClassesLoaded = if ($classFiles) { $classFiles.Count } else { 0 }
        PrivateFunctionsLoaded = if ($privateFunctions) { $privateFunctions.Count } else { 0 }
        PublicFunctionsLoaded = if ($publicFunctions) { $publicFunctions.Count } else { 0 }
        ConfigurationLoaded = Test-Path $configPath
    }
    
    Write-Verbose "Module loaded successfully: $($loadSummary | ConvertTo-Json -Compress)"
}
catch {
    Write-Error "Failed to load module components: $($_.Exception.Message)"
    throw
}

# Module Cleanup on Removal
$ExecutionContext.SessionState.Module.OnRemove = {
    Write-Verbose "Cleaning up module: $script:ModuleName"
    
    # Clean up module variables
    Remove-Variable -Name ModuleConfiguration -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name ModuleRoot -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name ModuleName -Scope Script -ErrorAction SilentlyContinue
    Remove-Variable -Name ModuleVersion -Scope Script -ErrorAction SilentlyContinue
    
    # Additional cleanup for enterprise integration
    # Example: Close database connections, clear caches, etc.
    
    Write-Verbose "Module cleanup completed: $script:ModuleName"
}

# Export module members (will be overridden by manifest)
# This is mainly for development/testing scenarios
if ($publicFunctions) {
    Export-ModuleMember -Function $publicFunctions.BaseName
}