#Requires -Module Pester

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Test-StandardsCompliance.ps1' | Resolve-Path

    # Invoke with -PassThru so the script returns its results object rather than
    # calling exit, which would terminate the Pester run.
    function Invoke-Compliance {
        param([string]$Path, [hashtable]$Extra = @{})
        & $script:ScriptPath -Path $Path -PassThru -InformationAction SilentlyContinue @Extra
    }

    function New-Fixture {
        param([string]$Name, [string]$Content)
        $file = Join-Path $script:FixturePath $Name
        Set-Content -LiteralPath $file -Value $Content -Encoding UTF8
        return $file
    }
}

Describe 'Test-StandardsCompliance' -Tag 'Unit', 'Tools' {

    BeforeEach {
        $script:FixturePath = Join-Path ([System.IO.Path]::GetTempPath()) "tsc-$([System.Guid]::NewGuid().ToString('N'))"
        New-Item -Path $script:FixturePath -ItemType Directory -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $script:FixturePath) {
            Remove-Item $script:FixturePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Parameter validation' {

        It 'Rejects a Path that does not exist' {
            { & $script:ScriptPath -Path (Join-Path $script:FixturePath 'nope') -PassThru -InformationAction SilentlyContinue } |
                Should-Throw
        }

        It 'Rejects an unsupported OutputFormat' {
            { & $script:ScriptPath -Path $script:FixturePath -OutputFormat 'Interpretive-Dance' -PassThru -InformationAction SilentlyContinue } |
                Should-Throw -ExceptionMessage '*ValidateSet*'
        }
    }

    Context 'Analysis results' {

        It 'Returns a results object when -PassThru is supplied' {
            New-Fixture -Name 'Get-Clean.ps1' -Content @'
function Get-Clean {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    Write-Output $Name
}
'@
            $result = Invoke-Compliance -Path $script:FixturePath

            $result | Should-NotBeNull
            $result.TotalFiles | Should-Be 1
            $result.CorrelationId | Should-NotBeNull
            @('PASSED', 'WARNING', 'FAILED') | Should-Any { $_ -eq $result.Summary.OverallStatus }
        }

        It 'Counts every PowerShell file it finds' {
            New-Fixture -Name 'One.ps1' -Content 'Write-Output 1'
            New-Fixture -Name 'Two.psm1' -Content 'Write-Output 2'
            New-Fixture -Name 'Three.psd1' -Content '@{ ModuleVersion = ''1.0.0'' }'

            (Invoke-Compliance -Path $script:FixturePath).TotalFiles | Should-Be 3
        }

        It 'Accepts a single file as the Path' {
            $file = New-Fixture -Name 'Single.ps1' -Content 'Write-Output 1'

            (Invoke-Compliance -Path $file).TotalFiles | Should-Be 1
        }
    }

    Context 'Community standards detection' {

        It 'Flags a function using a non-approved verb' {
            New-Fixture -Name 'BadVerb.ps1' -Content @'
function Process-Thing {
    param([string]$Data)
    Write-Output $Data
}
'@
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.ComplianceIssues.RuleName | Should-ContainCollection 'UseApprovedVerbs'
            ($result.ComplianceIssues | Where-Object RuleName -eq 'UseApprovedVerbs').Message | Should-MatchString 'Process'
        }

        It 'Does not flag a function using an approved verb' {
            New-Fixture -Name 'GoodVerb.ps1' -Content @'
function Get-Thing {
    param([string]$Data)
    Write-Output $Data
}
'@
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.ComplianceIssues.RuleName | Should-NotContainCollection 'UseApprovedVerbs'
        }
    }

    Context 'Security detection' {

        It 'Flags a hardcoded password' {
            New-Fixture -Name 'Secret.ps1' -Content @'
$config = @{
    password = "hunter2plus"
}
Write-Output $config
'@
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.SecurityIssues | Should-NotBeNull
            $result.SecurityIssues.Type | Should-ContainCollection 'HardcodedPassword'
        }

        It 'Does not flag a file with no secrets' {
            New-Fixture -Name 'NoSecret.ps1' -Content 'Write-Output "nothing to see"'

            (Invoke-Compliance -Path $script:FixturePath).SecurityIssues | Should-BeFalsy
        }
    }

    Context 'Version-aware array append rule' {

        # PowerShell 7.5 optimised += on object arrays, so the rule only applies to
        # files that declare a target where it is still O(n^2).

        It 'Flags += when the file declares no target version' {
            New-Fixture -Name 'NoRequires.ps1' -Content @'
$items = @()
foreach ($x in 1..10) { $items += $x }
Write-Output $items
'@
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.PerformanceIssues.Type | Should-ContainCollection 'ArrayAppending'
        }

        It 'Flags += when the file targets 5.1' {
            New-Fixture -Name 'Legacy.ps1' -Content @'
#requires -Version 5.1
$items = @()
foreach ($x in 1..10) { $items += $x }
Write-Output $items
'@
            (Invoke-Compliance -Path $script:FixturePath).PerformanceIssues.Type | Should-ContainCollection 'ArrayAppending'
        }

        It 'Does not flag += when the file targets 7.6' {
            New-Fixture -Name 'Modern.ps1' -Content @'
#requires -Version 7.6
$items = @()
foreach ($x in 1..10) { $items += $x }
Write-Output $items
'@
            (Invoke-Compliance -Path $script:FixturePath).PerformanceIssues.Type | Should-NotContainCollection 'ArrayAppending'
        }

        It 'Flags ArrayList on any version' {
            New-Fixture -Name 'Legacy-Collection.ps1' -Content @'
#requires -Version 7.6
$items = [System.Collections.ArrayList]::new()
[void]$items.Add(1)
Write-Output $items
'@
            (Invoke-Compliance -Path $script:FixturePath).PerformanceIssues.Type | Should-ContainCollection 'LegacyCollectionType'
        }
    }

    Context 'Output formats' {

        It 'Writes a JSON report when asked' {
            New-Fixture -Name 'Sample.ps1' -Content 'Write-Output 1'
            $out = Join-Path $script:FixturePath 'report.json'

            Invoke-Compliance -Path $script:FixturePath -Extra @{ OutputFormat = 'JSON'; OutputPath = $out } | Out-Null

            Test-Path $out | Should-BeTrue
            $null = Get-Content $out -Raw | ConvertFrom-Json   # invalid JSON throws, failing the test
            (Get-Content $out -Raw | ConvertFrom-Json).TotalFiles | Should-Be 1
        }
    }

    Context 'Empty input' {

        It 'Handles a directory with no PowerShell files' {
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.TotalFiles | Should-Be 0
        }

        It 'Emits exactly one results object, not one per code path' {
            New-Fixture -Name 'Sample.ps1' -Content 'Write-Output 1'

            @(Invoke-Compliance -Path $script:FixturePath).Count | Should-Be 1
        }
    }

    Context 'Reporting' {

        It 'Reports a clean run as PASSED' {
            New-Fixture -Name 'Clean.ps1' -Content @'
function Get-Clean {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    Write-Output $Name
}
'@
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.Summary.OverallStatus | Should-Be 'PASSED'
            $result.PassedFiles | Should-Be 1
            $result.FailedFiles | Should-Be 0
        }

        It 'Reports a run with a non-approved verb as FAILED' {
            New-Fixture -Name 'BadVerb.ps1' -Content 'function Process-Thing { Write-Output 1 }'
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.Summary.OverallStatus | Should-Be 'FAILED'
            $result.FailedFiles | Should-Be 1
            $result.Summary.CompliancePercentage | Should-Be 0
        }

        It 'Totals analysis time across files as a TimeSpan' {
            New-Fixture -Name 'A.ps1' -Content 'Write-Output 1'
            New-Fixture -Name 'B.ps1' -Content 'Write-Output 2'
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.Summary.TotalAnalysisTime | Should-HaveType ([TimeSpan])
            $result.Summary.TotalAnalysisTime.Ticks | Should-BeGreaterThan 0
        }

        It 'Produces per-file results with distinct issue sets' {
            New-Fixture -Name 'Clean.ps1' -Content 'Write-Output 1'
            New-Fixture -Name 'BadVerb.ps1' -Content 'function Process-Thing { Write-Output 1 }'
            $result = Invoke-Compliance -Path $script:FixturePath

            # Regression: the analysis used to mutate the *previous* file's result,
            # so issues leaked between files.
            $bad = $result.FileResults | Where-Object FileName -eq 'BadVerb.ps1'
            $clean = $result.FileResults | Where-Object FileName -eq 'Clean.ps1'
            $bad.Issues.Count | Should-BeGreaterThan 0
            $clean.Issues.Count | Should-Be 0
        }

        It 'Writes detailed output when -Detailed is supplied' {
            New-Fixture -Name 'BadVerb.ps1' -Content 'function Process-Thing { Write-Output 1 }'

            $output = & $script:ScriptPath -Path $script:FixturePath -PassThru -Detailed `
                -InformationAction Continue 6>&1 | Out-String

            $output | Should-MatchString 'BadVerb\.ps1'
        }

        It 'Skips test files when -ExcludeTests is supplied' {
            New-Fixture -Name 'Regular.ps1' -Content 'Write-Output 1'
            New-Fixture -Name 'Thing.Tests.ps1' -Content 'Write-Output 2'

            $withTests = Invoke-Compliance -Path $script:FixturePath
            $withoutTests = Invoke-Compliance -Path $script:FixturePath -Extra @{ ExcludeTests = $true }

            $withTests.TotalFiles | Should-Be 2
            $withoutTests.TotalFiles | Should-BeLessThan $withTests.TotalFiles
        }
    }

    Context 'Issue severity classification' {

        It 'Counts an analyzer Error as critical' {
            # PSAvoidUsingComputerNameHardcoded is an Error-severity rule
            New-Fixture -Name 'HardCoded.ps1' -Content @'
function Get-Thing {
    Get-CimInstance -ComputerName "SERVER01" -ClassName Win32_OperatingSystem
}
'@
            (Invoke-Compliance -Path $script:FixturePath).CriticalIssues | Should-BeGreaterThan 0
        }

        It 'Counts an analyzer Information finding as low' {
            New-Fixture -Name 'Positional.ps1' -Content @'
function Get-Thing {
    Write-Output "a" "b" "c"
}
Get-Thing
'@
            $result = Invoke-Compliance -Path $script:FixturePath
            ($result.LowIssues + $result.HighIssues) | Should-BeGreaterThan 0
        }

        It 'Counts a High-severity security pattern separately from Critical' {
            # Invoke-Expression is classified High, not Critical
            New-Fixture -Name 'Iex.ps1' -Content 'Invoke-Expression "Get-Date"'
            $result = Invoke-Compliance -Path $script:FixturePath

            $result.SecurityIssues.Type | Should-ContainCollection 'InvokeExpression'
            $result.HighIssues | Should-BeGreaterThan 0
        }
    }

    Context 'Detailed output' {

        It 'Marks a compliant file as passing' {
            New-Fixture -Name 'Clean.ps1' -Content @'
function Get-Clean {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Name)
    Write-Output $Name
}
'@
            $output = & $script:ScriptPath -Path $script:FixturePath -PassThru -Detailed `
                -InformationAction Continue 6>&1 | Out-String

            $output | Should-MatchString '\[PASS\]'
        }

        It 'Lists security and performance findings when -Detailed is supplied' {
            New-Fixture -Name 'Messy.ps1' -Content @'
#requires -Version 5.1
Invoke-Expression "Get-Date"
$items = @()
foreach ($x in 1..5) { $items += $x }
Write-Output $items
'@
            $output = & $script:ScriptPath -Path $script:FixturePath -PassThru -Detailed `
                -InformationAction Continue 6>&1 | Out-String

            $output | Should-MatchString 'Security Issues'
            $output | Should-MatchString 'Performance Issues'
        }
    }

    Context 'Output failures' {

        It 'Warns rather than throwing when the report cannot be written' {
            New-Fixture -Name 'Sample.ps1' -Content 'Write-Output 1'
            $unwritable = Join-Path $script:FixturePath 'no-such-directory\report.json'

            $result = & $script:ScriptPath -Path $script:FixturePath -PassThru `
                -OutputFormat 'JSON' -OutputPath $unwritable `
                -InformationAction SilentlyContinue -WarningAction SilentlyContinue -WarningVariable warned

            # The analysis result still comes back; only the file write failed
            $result.TotalFiles | Should-Be 1
            "$warned" | Should-MatchString 'Failed to save results'
        }
    }

    Context 'Additional output formats' {

        It 'Writes an XML report' {
            New-Fixture -Name 'Sample.ps1' -Content 'Write-Output 1'
            $out = Join-Path $script:FixturePath 'report.xml'

            Invoke-Compliance -Path $script:FixturePath -Extra @{ OutputFormat = 'XML'; OutputPath = $out } | Out-Null

            Test-Path $out | Should-BeTrue
            (Get-Item $out).Length | Should-BeGreaterThan 0
        }

        It 'Writes an HTML report' {
            New-Fixture -Name 'Sample.ps1' -Content 'Write-Output 1'
            $out = Join-Path $script:FixturePath 'report.html'

            Invoke-Compliance -Path $script:FixturePath -Extra @{ OutputFormat = 'HTML'; OutputPath = $out } | Out-Null

            Test-Path $out | Should-BeTrue
            Get-Content $out -Raw | Should-MatchString '<html'
        }
    }
}
