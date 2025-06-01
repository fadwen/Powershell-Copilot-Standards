# Tools/Install-CopilotStandards.ps1
<#
.SYNOPSIS
    Installs PowerShell Copilot Standards in a project

.DESCRIPTION
    Copies or links Copilot instruction files to enable enterprise
    PowerShell development standards in new or existing projects

.PARAMETER ProjectPath
    Path to the target project directory

.PARAMETER StandardsType
    Type of standards to install: Basic, Module, Enterprise

.PARAMETER LinkType
    How to install: Copy, Symlink, Submodule

.EXAMPLE
    .\Install-CopilotStandards.ps1 -ProjectPath "C:\Projects\MyModule" -StandardsType "Module"

    Installs module-specific standards in the target project

.EXAMPLE
    .\Install-CopilotStandards.ps1 -ProjectPath "." -StandardsType "Basic" -LinkType "Symlink"

    Creates symbolic links to standards in current directory

.NOTES
    Author: Jeffrey Stuhr
    Version: 1.0.0

    REQUIREMENTS:
    - PowerShell 5.1+ or PowerShell 7.x
    - Write permissions to target directory
    - For Symlink: Administrator privileges (Windows)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to the target project directory")]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Container)) {
            throw "Directory '$_' does not exist"
        }
        $true
    })]
    [string]$ProjectPath,

    [Parameter(HelpMessage = "Type of standards to install")]
    [ValidateSet('Basic', 'Module', 'Enterprise')]
    [string]$StandardsType = 'Basic',

    [Parameter(HelpMessage = "How to install the standards")]
    [ValidateSet('Copy', 'Symlink', 'Submodule')]
    [string]$LinkType = 'Copy'
)

begin {
    $ErrorActionPreference = 'Stop'
    $correlationId = [System.Guid]::NewGuid()

    # Get the standards repository path (assuming this script is in Tools/ folder)
    $StandardsPath = Split-Path $PSScriptRoot -Parent

    Write-Information "Installing PowerShell Copilot Standards..." -InformationAction Continue
    Write-Verbose "CorrelationId: $correlationId"
    Write-Verbose "Standards Path: $StandardsPath"
    Write-Verbose "Project Path: $ProjectPath"
    Write-Verbose "Standards Type: $StandardsType"
    Write-Verbose "Link Type: $LinkType"
}

process {
    try {
        # Resolve full paths
        $ProjectPath = Resolve-Path $ProjectPath
        $githubPath = Join-Path $ProjectPath ".github"

        Write-Information "Setting up project structure..." -InformationAction Continue

        # Create .github structure if it doesn't exist
        if (-not (Test-Path $githubPath)) {
            if ($PSCmdlet.ShouldProcess($githubPath, "Create .github directory")) {
                New-Item -Path $githubPath -ItemType Directory -Force | Out-Null
                Write-Information "Created .github directory" -InformationAction Continue
            }
        }

        # Install standards based on link type
        Write-Information "Installing standards files..." -InformationAction Continue

        switch ($LinkType) {
            'Copy' {
                if ($PSCmdlet.ShouldProcess("Standards files", "Copy to project")) {
                    # Copy main instructions
                    $sourceInstructions = Join-Path $StandardsPath ".github\copilot-instructions.md"
                    $destInstructions = Join-Path $githubPath "copilot-instructions.md"

                    if (Test-Path $sourceInstructions) {
                        Copy-Item -Path $sourceInstructions -Destination $destInstructions -Force
                        Write-Information "Copied main instructions" -InformationAction Continue
                    }

                    # Copy instructions directory
                    $sourceInstructionsDir = Join-Path $StandardsPath ".github\instructions"
                    $destInstructionsDir = Join-Path $githubPath "instructions"

                    if (Test-Path $sourceInstructionsDir) {
                        Copy-Item -Path $sourceInstructionsDir -Destination $destInstructionsDir -Recurse -Force
                        Write-Information "Copied instruction files" -InformationAction Continue
                    }

                    # Copy prompts directory
                    $sourcePromptsDir = Join-Path $StandardsPath ".github\prompts"
                    $destPromptsDir = Join-Path $githubPath "prompts"

                    if (Test-Path $sourcePromptsDir) {
                        Copy-Item -Path $sourcePromptsDir -Destination $destPromptsDir -Recurse -Force
                        Write-Information "Copied prompt files" -InformationAction Continue
                    }
                }
            }

            'Symlink' {
                if ($PSCmdlet.ShouldProcess("Standards files", "Create symbolic links")) {
                    $sourceInstructions = Join-Path $StandardsPath ".github\copilot-instructions.md"
                    $destInstructions = Join-Path $githubPath "copilot-instructions.md"

                    if (Test-Path $sourceInstructions) {
                        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                            # Windows - check for admin privileges
                            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
                            if (-not $isAdmin) {
                                Write-Warning "Symbolic links on Windows require Administrator privileges. Falling back to Copy method."
                                $LinkType = 'Copy'
                                # Recursively call with Copy method
                                & $MyInvocation.MyCommand.Path -ProjectPath $ProjectPath -StandardsType $StandardsType -LinkType 'Copy'
                                return
                            }
                            cmd /c mklink "$destInstructions" "$sourceInstructions" 2>$null
                        } else {
                            # Linux/macOS
                            New-Item -ItemType SymbolicLink -Path $destInstructions -Target $sourceInstructions -Force
                        }
                        Write-Information "Created symbolic links" -InformationAction Continue
                    }
                }
            }

            'Submodule' {
                if ($PSCmdlet.ShouldProcess($ProjectPath, "Add git submodule")) {
                    Push-Location $ProjectPath
                    try {
                        # Check if this is a git repository
                        if (-not (Test-Path ".git")) {
                            throw "Target directory is not a git repository. Initialize with 'git init' first."
                        }

                        git submodule add https://github.com/fadwen/PowerShell-Copilot-Standards.git .copilot-standards 2>&1

                        # Create symbolic link to main instructions
                        $submoduleInstructions = ".copilot-standards\.github\copilot-instructions.md"
                        $destInstructions = Join-Path $githubPath "copilot-instructions.md"

                        if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                            cmd /c mklink "$destInstructions" "$submoduleInstructions" 2>$null
                        } else {
                            New-Item -ItemType SymbolicLink -Path $destInstructions -Target $submoduleInstructions -Force
                        }

                        Write-Information "Added as git submodule" -InformationAction Continue
                    }
                    finally {
                        Pop-Location
                    }
                }
            }
        }

        # Create project structure based on standards type
        Write-Information "Creating project structure..." -InformationAction Continue

        $foldersToCreate = switch ($StandardsType) {
            'Basic' {
                @('Tests', 'Troubleshooting')
            }
            'Module' {
                @('Public', 'Private', 'Classes', 'Tests\Unit', 'Tests\Integration', 'Troubleshooting\Common', 'Troubleshooting\Security', 'Troubleshooting\Performance', 'Documentation')
            }
            'Enterprise' {
                @('Public', 'Private', 'Classes', 'Configuration', 'Tests\Unit', 'Tests\Integration', 'Tests\Security', 'Troubleshooting\Common', 'Troubleshooting\Security', 'Troubleshooting\Performance', 'Troubleshooting\Integration', 'Documentation', 'Scripts', 'Tools')
            }
        }

        foreach ($folder in $foldersToCreate) {
            $folderPath = Join-Path $ProjectPath $folder
            if (-not (Test-Path $folderPath)) {
                if ($PSCmdlet.ShouldProcess($folderPath, "Create directory")) {
                    New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
                }
            }
        }

        Write-Information "Created $StandardsType project structure" -InformationAction Continue

        # Create basic .gitignore if it doesn't exist
        $gitignorePath = Join-Path $ProjectPath ".gitignore"
        if (-not (Test-Path $gitignorePath)) {
            if ($PSCmdlet.ShouldProcess($gitignorePath, "Create .gitignore")) {
                $gitignoreContent = @"
# PowerShell
*.ps1.bak
*.psm1.bak
*.psd1.bak
.vscode/
*.log
Temp/
*.tmp

# Test Results
TestResults/
coverage.xml
"@
                $gitignoreContent | Out-File -FilePath $gitignorePath -Encoding UTF8
                Write-Information "Created .gitignore file" -InformationAction Continue
            }
        }

        Write-Information "PowerShell Copilot Standards installed successfully!" -InformationAction Continue
        Write-Information "Next steps:" -InformationAction Continue
        Write-Information "  1. Enable prompt files in VS Code settings:" -InformationAction Continue
        Write-Information "     `"chat.promptFiles`": true" -InformationAction Continue
        Write-Information "     `"github.copilot.chat.codeGeneration.useInstructionFiles`": true" -InformationAction Continue
        Write-Information "  2. Test with /new-function in Copilot Chat" -InformationAction Continue
        Write-Information "  3. Run .\Tools\Test-StandardsCompliance.ps1 to validate" -InformationAction Continue
        Write-Information "  4. Create your first function using enterprise standards" -InformationAction Continue

    }
    catch {
        Write-Error "Failed to install standards: $($_.Exception.Message) (CorrelationId: $correlationId)"
        throw
    }
}

end {
    Write-Verbose "Installation completed - CorrelationId: $correlationId"
}
