#Requires -Module Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Install-CopilotStandards.ps1' | Resolve-Path
}

Describe 'Install-CopilotStandards' -Tag 'Unit', 'Tools' {

    BeforeEach {
        # A fresh project directory per test - the script writes to disk, so tests
        # must never share one. Sited under $TestDrive, which Pester creates and
        # removes per container and keeps isolated between files even under
        # parallel, so no AfterEach cleanup is needed. $TestDrive is a real
        # filesystem path, unlike the TestDrive: PSDrive, so it works with the
        # native and .NET calls this script makes.
        $script:ProjectPath = Join-Path $TestDrive "ics-$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:ProjectPath -ItemType Directory -Force | Out-Null
    }

    Context 'Parameter validation' {

        It 'Rejects a ProjectPath that does not exist' {
            $missing = Join-Path $script:ProjectPath 'no-such-directory'
            { & $script:ScriptPath -ProjectPath $missing -InformationAction SilentlyContinue } |
                Should-Throw -ExceptionMessage '*does not exist*'
        }

        It 'Rejects a ProjectPath that is a file rather than a directory' {
            $file = Join-Path $script:ProjectPath 'a-file.txt'
            Set-Content -Path $file -Value 'not a directory'
            { & $script:ScriptPath -ProjectPath $file -InformationAction SilentlyContinue } |
                Should-Throw -ExceptionMessage '*does not exist*'
        }

        It 'Rejects an unknown StandardsType' {
            { & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'NotAType' -InformationAction SilentlyContinue } |
                Should-Throw -ExceptionMessage '*ValidateSet*'
        }

        It 'Rejects an unknown LinkType' {
            { & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Telepathy' -InformationAction SilentlyContinue } |
                Should-Throw -ExceptionMessage '*ValidateSet*'
        }
    }

    Context 'Copy installation' {

        BeforeEach {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Basic' -LinkType 'Copy' -InformationAction SilentlyContinue
        }

        It 'Creates the .github directory' {
            Test-Path (Join-Path $script:ProjectPath '.github') | Should-BeTrue
        }

        It 'Copies the main Copilot instructions' {
            Test-Path (Join-Path $script:ProjectPath '.github/copilot-instructions.md') | Should-BeTrue
        }

        It 'Copies the instructions directory with its content' {
            $dir = Join-Path $script:ProjectPath '.github/instructions'
            Test-Path $dir | Should-BeTrue
            (Get-ChildItem $dir -Filter '*.instructions.md').Count | Should-BeGreaterThan 0
        }

        It 'Copies the prompts directory with its content' {
            $dir = Join-Path $script:ProjectPath '.github/prompts'
            Test-Path $dir | Should-BeTrue
            (Get-ChildItem $dir -Filter '*.prompt.md').Count | Should-BeGreaterThan 0
        }

        It 'Creates a .gitignore covering PowerShell and test artifacts' {
            $gitignore = Join-Path $script:ProjectPath '.gitignore'
            Test-Path $gitignore | Should-BeTrue
            $content = Get-Content $gitignore -Raw
            $content | Should-MatchString '\*\.ps1\.bak'
            $content | Should-MatchString 'TestResults/'
        }
    }

    Context 'Project structure per StandardsType' {

        It 'Basic creates Tests and Troubleshooting' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Basic' -InformationAction SilentlyContinue

            Test-Path (Join-Path $script:ProjectPath 'Tests') | Should-BeTrue
            Test-Path (Join-Path $script:ProjectPath 'Troubleshooting') | Should-BeTrue
        }

        It 'Module adds the module layout' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Module' -InformationAction SilentlyContinue

            foreach ($folder in 'Public', 'Private', 'Classes', 'Documentation') {
                Test-Path (Join-Path $script:ProjectPath $folder) | Should-BeTrue
            }
            Test-Path (Join-Path $script:ProjectPath 'Tests/Unit') | Should-BeTrue
            Test-Path (Join-Path $script:ProjectPath 'Tests/Integration') | Should-BeTrue
        }

        It 'Enterprise adds Configuration, Scripts, Tools and a security test folder' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Enterprise' -InformationAction SilentlyContinue

            foreach ($folder in 'Configuration', 'Scripts', 'Tools') {
                Test-Path (Join-Path $script:ProjectPath $folder) | Should-BeTrue
            }
            Test-Path (Join-Path $script:ProjectPath 'Tests/Security') | Should-BeTrue
            Test-Path (Join-Path $script:ProjectPath 'Troubleshooting/Integration') | Should-BeTrue
        }
    }

    Context 'Idempotence and non-destructive behaviour' {

        It 'Does not overwrite an existing .gitignore' {
            $gitignore = Join-Path $script:ProjectPath '.gitignore'
            Set-Content -Path $gitignore -Value '# hand-written, keep me'

            & $script:ScriptPath -ProjectPath $script:ProjectPath -InformationAction SilentlyContinue

            Get-Content $gitignore -Raw | Should-MatchString 'hand-written, keep me'
        }

        It 'Can run twice without error' {
            # Pester 6 has no Should-NotThrow; a second run that throws fails the test
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Module' -InformationAction SilentlyContinue
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Module' -InformationAction SilentlyContinue
        }
    }

    Context 'WhatIf support' {

        It 'Creates nothing when -WhatIf is supplied' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -StandardsType 'Enterprise' -WhatIf -InformationAction SilentlyContinue

            Test-Path (Join-Path $script:ProjectPath '.github') | Should-BeFalse
            Test-Path (Join-Path $script:ProjectPath 'Public') | Should-BeFalse
            Test-Path (Join-Path $script:ProjectPath '.gitignore') | Should-BeFalse
        }

        It 'Installs no sync workflow when -WhatIf is supplied' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow -WhatIf `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            Test-Path (Join-Path $script:ProjectPath '.github/workflows') | Should-BeFalse
        }
    }

    Context 'Sync workflow installation' {

        It 'Installs no workflow by default' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -InformationAction SilentlyContinue

            Test-Path (Join-Path $script:ProjectPath '.github/workflows') | Should-BeFalse
        }

        It 'Installs the workflow when -IncludeSyncWorkflow is supplied' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            Test-Path (Join-Path $script:ProjectPath '.github/workflows/sync-copilot-standards.yml') |
                Should-BeTrue
        }

        It 'Installs a workflow that mirrors the three instruction paths' {
            & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            $content = Get-Content (Join-Path $script:ProjectPath '.github/workflows/sync-copilot-standards.yml') -Raw

            $content | Should-MatchString 'copilot-instructions\.md'
            $content | Should-MatchString 'instructions prompts'
            $content | Should-MatchString 'workflow_dispatch'
        }

        It 'Installs a workflow free of the deprecated Node 20 action majors' {
            # actions/checkout below v7 and create-pull-request below v8 declare
            # node20, which GitHub-hosted runners now warn about.
            & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            $content = Get-Content (Join-Path $script:ProjectPath '.github/workflows/sync-copilot-standards.yml') -Raw

            $content | Should-MatchString 'actions/checkout@v7'
            $content | Should-MatchString 'peter-evans/create-pull-request@v8'
            $content | Should-NotMatchString 'actions/checkout@v[1-6]\b'
        }

        It 'Does not overwrite a workflow the project has already tuned' {
            $workflowDir = Join-Path $script:ProjectPath '.github/workflows'
            New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null
            $existing = Join-Path $workflowDir 'sync-copilot-standards.yml'
            Set-Content -Path $existing -Value '# hand-tuned, keep me'

            & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            Get-Content $existing -Raw | Should-MatchString 'hand-tuned, keep me'
        }

        It 'Warns about the pull request permission the workflow needs' {
            $warnings = & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow `
                -InformationAction SilentlyContinue 3>&1 | Out-String

            $warnings | Should-MatchString 'approve pull requests'
        }

        It 'Leaves other workflows in the project alone' {
            $workflowDir = Join-Path $script:ProjectPath '.github/workflows'
            New-Item -Path $workflowDir -ItemType Directory -Force | Out-Null
            $unrelated = Join-Path $workflowDir 'ci.yml'
            Set-Content -Path $unrelated -Value '# the project''s own CI'

            & $script:ScriptPath -ProjectPath $script:ProjectPath -IncludeSyncWorkflow `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            Get-Content $unrelated -Raw | Should-MatchString "project's own CI"
        }
    }

    Context 'Symlink installation' {

        It 'Still installs the instructions, whether it links or falls back to copy' {
            # Creating a symlink on Windows needs elevation. Unelevated, the script
            # warns and re-invokes itself with -LinkType Copy. Both outcomes must
            # leave the caller with usable instructions, and CI may run either way.
            & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Symlink' `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue

            Test-Path (Join-Path $script:ProjectPath '.github/copilot-instructions.md') | Should-BeTrue
        }
    }

    Context 'Submodule installation' {

        It 'Refuses a target that is not a git repository' {
            {
                & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Submodule' `
                    -InformationAction SilentlyContinue
            } | Should-Throw -ExceptionMessage '*not a git repository*'
        }

        It 'Leaves the working directory unchanged after failing' {
            $before = (Get-Location).Path
            try {
                & $script:ScriptPath -ProjectPath $script:ProjectPath -LinkType 'Submodule' `
                    -InformationAction SilentlyContinue -ErrorAction SilentlyContinue
            }
            catch { }
            (Get-Location).Path | Should-Be $before
        }
    }

    Context 'Guidance it prints' {

        It 'Does not recommend the VS Code settings deprecated in 1.102' {
            $output = & $script:ScriptPath -ProjectPath $script:ProjectPath -InformationAction Continue 6>&1 |
                Out-String

            $output | Should-NotMatchString 'chat\.promptFiles'
            $output | Should-NotMatchString 'useInstructionFiles'
        }
    }
}
