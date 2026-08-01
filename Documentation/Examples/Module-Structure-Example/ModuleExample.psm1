<#
    ModuleExample root module.

    Loads classes first, then private functions, then public ones - classes must be
    available before any function that returns one is defined. Export is controlled
    by the manifest's FunctionsToExport rather than a wildcard here, so the public
    surface stays explicit.

    Quality Standards: https://github.com/fadwen/Powershell-Copilot-Standards
#>

$ErrorActionPreference = 'Stop'

#region Classes
# Classes load first: Get-ExampleData returns an ExampleServiceResult, so the type
# must exist before that function is dot-sourced.
$ClassFiles = Get-ChildItem -Path "$PSScriptRoot/Classes/*.ps1" -ErrorAction SilentlyContinue
foreach ($ClassFile in $ClassFiles) {
    try {
        . $ClassFile.FullName
        Write-Verbose "Loaded class: $($ClassFile.BaseName)"
    }
    catch {
        throw "Failed to load class $($ClassFile.BaseName): $($_.Exception.Message)"
    }
}
#endregion

#region Private Functions
# Internal helpers - deliberately not exported by the manifest.
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded private function: $($Function.BaseName)"
    }
    catch {
        throw "Failed to load private function $($Function.BaseName): $($_.Exception.Message)"
    }
}
#endregion

#region Public Functions
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded public function: $($Function.BaseName)"
    }
    catch {
        throw "Failed to load public function $($Function.BaseName): $($_.Exception.Message)"
    }
}
#endregion

Write-Verbose "ModuleExample loaded: $($PublicFunctions.Count) public, $($PrivateFunctions.Count) private"
