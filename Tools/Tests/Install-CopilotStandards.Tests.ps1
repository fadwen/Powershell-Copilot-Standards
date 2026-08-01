#Requires -Module Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Install-CopilotStandards.ps1' | Resolve-Path
}

Describe 'Install-CopilotStandards' -Tag 'Unit', 'Tools' {

    BeforeEach {
        # A fresh throwaway project directory per test - the script writes to disk,
        # so tests must never share one.
        $script:ProjectPath = Join-Path ([System.IO.Path]::GetTempPath()) "ics-$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:ProjectPath -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:ProjectPath) {
            Remove-Item $script:ProjectPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter validation' {

        It 'Rejects a ProjectPath that does not exist' {
            $missing = Join-Path $script:ProjectPath 'no-such-directory'
            { & $script:ScriptPath -ProjectPath $missing -InformationAction SilentlyContinue } |
                Should -Throw '*does not exist*'
        }

        It 'Rejects a ProjectPath that is a file rather than a directory' {
            $file = Join-Path $script:ProjectPath 'a-file.txt'
            Set-Content -Path $file -Value 'not a directory'
            { & $script:ScriptPath -ProjectPath $file -InformationAction SilentlyContinue } |
                Should -Throw '*does not exist*'
        }

        It 'Rejects an unknown StandardsType' {
            { & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'NotAType' -InformationAction SilentlyContinue } |
                Should -Throw '*ValidateSet*'
        }

        It 'Rejects an unknown LinkType' {
            { & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Telepathy' -InformationAction SilentlyContinue } |
                Should -Throw '*ValidateSet*'
        }
    }

    Context 'Copy installation' {

        BeforeEach {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Basic' -LinkType 'Copy' -InformationAction SilentlyContinue
        }

        It 'Creates the .github directory' {
            Join-Path $script:ProjectPath '.github' | Should -Exist
        }

        It 'Copies the main Copilot instructions' {
            Join-Path $script:ProjectPath '.github/copilot-instructions.md' | Should -Exist
        }

        It 'Copies the instructions directory with its content' {
            $dir = Join-Path $script:ProjectPath '.github/instructions'
            $dir | Should -Exist
            (Get-ChildItem $dir -Filter '*.instructions.md').Count | Should -BeGreaterThan 0
        }

        It 'Copies the prompts directory with its content' {
            $dir = Join-Path $script:ProjectPath '.github/prompts'
            $dir | Should -Exist
            (Get-ChildItem $dir -Filter '*.prompt.md').Count | Should -BeGreaterThan 0
        }

        It 'Creates a .gitignore covering PowerShell and test artifacts' {
            $gitignore = Join-Path $script:ProjectPath '.gitignore'
            $gitignore | Should -Exist
            $content = Get-Content $gitignore -Raw
            $content | Should -Match '\*\.ps1\.bak'
            $content | Should -Match 'TestResults/'
        }
    }

    Context 'Project structure per StandardsType' {

        It 'Basic creates Tests and Troubleshooting' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Basic' -InformationAction SilentlyContinue

            Join-Path $script:ProjectPath 'Tests' | Should -Exist
            Join-Path $script:ProjectPath 'Troubleshooting' | Should -Exist
        }

        It 'Module adds the module layout' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Module' -InformationAction SilentlyContinue

            foreach ($folder in 'Public', 'Private', 'Classes', 'Documentation') {
                Join-Path $script:ProjectPath $folder | Should -Exist
            }
            Join-Path $script:ProjectPath 'Tests/Unit' | Should -Exist
            Join-Path $script:ProjectPath 'Tests/Integration' | Should -Exist
        }

        It 'Enterprise adds Configuration, Scripts, Tools and a security test folder' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Enterprise' -InformationAction SilentlyContinue

            foreach ($folder in 'Configuration', 'Scripts', 'Tools') {
                Join-Path $script:ProjectPath $folder | Should -Exist
            }
            Join-Path $script:ProjectPath 'Tests/Security' | Should -Exist
            Join-Path $script:ProjectPath 'Troubleshooting/Integration' | Should -Exist
        }
    }

    Context 'Idempotence and non-destructive behaviour' {

        It 'Does not overwrite an existing .gitignore' {
            $gitignore = Join-Path $script:ProjectPath '.gitignore'
            Set-Content -Path $gitignore -Value '# hand-written, keep me'

            & $script:ScriptPath -ProjectPath $script:ProjectPath -InformationAction SilentlyContinue

            Get-Content $gitignore -Raw | Should -Match 'hand-written, keep me'
        }

        It 'Can run twice without error' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Module' -InformationAction SilentlyContinue
            { & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Module' -InformationAction SilentlyContinue } |
                Should -Not -Throw
        }
    }

    Context 'WhatIf support' {

        It 'Creates nothing when -WhatIf is supplied' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Enterprise' -WhatIf -InformationAction SilentlyContinue

            Join-Path $script:ProjectPath '.github' | Should -Not -Exist
            Join-Path $script:ProjectPath 'Public' | Should -Not -Exist
            Join-Path $script:ProjectPath '.gitignore' | Should -Not -Exist
        }
    }

    Context 'Symlink installation' {

        It 'Still installs the instructions, whether it links or falls back to copy' {
            # Creating a symlink on Windows needs elevation. Unelevated, the script
            # warns and re-invokes itself with -LinkType Copy. Both outcomes must
            # leave the caller with usable instructions, and CI may run either way.
            & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Symlink' `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            Join-Path $script:ProjectPath '.github/copilot-instructions.md' | Should -Exist
        }
    }

    Context 'Submodule installation' {

        It 'Refuses a target that is not a git repository' {
            {
                & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Submodule' `
                    -InformationAction SilentlyContinue
            } | Should -Throw '*not a git repository*'
        }

        It 'Leaves the working directory unchanged after failing' {
            $before = (Get-Location).Path
            try {
                & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Submodule' `
                    -InformationAction SilentlyContinue -ErrorAction SilentlyContinue
            }
            catch { }
            (Get-Location).Path | Should -Be $before
        }
    }

    Context 'Guidance it prints' {

        It 'Does not recommend the VS Code settings deprecated in 1.102' {
            $output = & $script:ScriptPath -ProjectPath $script:ProjectPath -InformationAction Continue 6>&1 |
                Out-String

            $output | Should -Not -Match 'chat\.promptFiles'
            $output | Should -Not -Match 'useInstructionFiles'
        }
    }
}
