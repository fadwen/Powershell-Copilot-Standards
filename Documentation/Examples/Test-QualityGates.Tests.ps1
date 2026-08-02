#Requires -Module Pester

BeforeAll {
    $script:SourcePath = Join-Path $PSScriptRoot 'Test-QualityGates.ps1'
    . $script:SourcePath

    # Parse once. The file-level checks below inspect the AST rather than raw
    # text, because this file documents the patterns it violates - a regex for
    # 'Write-Host' matches the comments describing the violation as readily as
    # the call itself, and would report inflated counts that never go to zero.
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:SourcePath, [ref]$null, [ref]$null)

    $script:Functions = $script:Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

    function Get-CallsTo {
        param([string]$Name)
        $script:Ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -eq $Name
            }, $true)
    }

    # Test-QualityGates calls Get-ADUser, which ships with RSAT and is absent on CI
    # runners and non-Windows hosts. Pester cannot mock a command that does not
    # exist, so define a stub for Mock to replace. Every test that exercises the
    # function must mock it - otherwise the stub returns nothing and the function's
    # own "User not found" guard fires.
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        function Get-ADUser {
            [CmdletBinding()]
            param(
                [Parameter(Mandatory)] $Identity,
                [Parameter()] $Properties,
                [Parameter()] $Server
            )
        }
    }
}

Describe "Test-QualityGates Function" -Tag "Unit", "QualityDemo" {

    Context "Parameter Validation" {
        BeforeEach {
            # Without this the stub returns $null and the function throws "User not found"
            Mock Get-ADUser {
                [PSCustomObject]@{ Name = 'Test User'; SamAccountName = 'testuser'; Enabled = $true }
            }
        }

        It "Should accept valid UserName parameter" {
            # Pester 6 has no Should-NotThrow. Calling the code is the assertion -
            # an unhandled exception fails the test.
            Test-QualityGates -UserName "testuser"
        }

        It "Should handle empty ServerList gracefully" {
            $result = Test-QualityGates -UserName "testuser" -ServerList @()
            $result | Should-NotBeNull
            $result.ServersProcessed | Should-Be 0
        }

        It "Should process multiple servers" {
            $servers = @("server1", "server2", "server3")
            $result = Test-QualityGates -UserName "testuser" -ServerList $servers
            $result.ServersProcessed | Should-Be 3
        }
    }

    Context "Error Handling" {
        BeforeEach {
            # Mock external dependencies to control test behavior
            Mock Get-ADUser {
                throw "User not found"
            }
        }

        It "Should handle user not found errors" {
            # -ExceptionMessage matches with wildcards, so the leading/trailing * are
            # needed for a substring match - unlike classic Should -Throw.
            { Test-QualityGates -UserName "nonexistentuser" } |
                Should-Throw -ExceptionMessage '*User not found*'
        }
    }

    Context "Output Validation" {
        BeforeEach {
            # Mock successful AD lookup
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    Name = "Test User"
                    SamAccountName = "testuser"
                    Enabled = $true
                }
            }
        }

        It "Should return PSCustomObject with required properties" {
            $result = Test-QualityGates -UserName "testuser" -ServerList @("server1")

            $result | Should-NotBeNull
            $result.UserName | Should-Be "testuser"
            $result.ServersProcessed | Should-Be 1
            $result.ProcessedAt | Should-HaveType ([datetime])
        }

        It "Should include log size information" {
            $result = Test-QualityGates -UserName "testuser"
            $result.LogSize | Should-BeGreaterThan 0
        }

        It "Should include database query information" {
            $result = Test-QualityGates -UserName "testuser"
            $result.DatabaseQuery | Should-MatchString "SELECT.*FROM.*Users"
        }
    }
}

Describe "Get-TestResult Function" -Tag "Unit", "GoodExample" {

    Context "Proper Implementation Validation" {
        It "Is named with an approved verb and a singular noun" {
            $verb, $noun = 'Get-TestResult' -split '-', 2

            (Get-Verb).Verb | Should-Any { $_ -eq $verb }
            # PSUseSingularNouns fires on a trailing 's'. The plural form is what
            # this function was called before, and it was a real analyzer warning.
            $noun.EndsWith('s') | Should-BeFalse
        }

        It "Should accept mandatory TestName parameter" {
            Get-TestResult -TestName "SecurityTest"
        }

        It "Should generate correlation ID automatically" {
            $result = Get-TestResult -TestName "AutoTest"
            $result.CorrelationId | Should-NotBeEmptyString
            $result.CorrelationId |
                Should-MatchString "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        }

        It "Should handle empty test name appropriately" {
            # A Mandatory [string] rejects '' during binding, before the body runs,
            # so the message comes from PowerShell - not the function's own guard.
            { Get-TestResult -TestName "" } | Should-Throw -ExceptionMessage '*empty string*'
        }

        It "Should handle whitespace-only test name" {
            # Whitespace binds fine, so the function's own validation produces this one
            { Get-TestResult -TestName "   " } |
                Should-Throw -ExceptionMessage '*cannot be empty or whitespace*'
        }

        It "Should return properly typed result" {
            $result = Get-TestResult -TestName "TypeTest"
            # PSTypeName is consumed when constructing the object; it sets the type
            # name rather than remaining as a readable property.
            $result.PSObject.TypeNames[0] | Should-Be "TestResult"
            $result.Status | Should-Be "Passed"
        }

        It "Should include all required properties" {
            $result = Get-TestResult -TestName "PropertyTest"

            $result.TestName | Should-Be "PropertyTest"
            $result.Status | Should-NotBeEmptyString
            $result.CorrelationId | Should-NotBeEmptyString
            $result.ExecutedAt | Should-HaveType ([datetime])
        }
    }

    Context "Parameter Validation Best Practices" {
        It "Should trim whitespace from TestName parameter" {
            $result = Get-TestResult -TestName "  TrimTest  "
            $result.TestName | Should-Be "TrimTest"
        }

        It "Should accept custom correlation ID" {
            $customId = [System.Guid]::NewGuid().ToString()
            $result = Get-TestResult -TestName "CustomIdTest" -CorrelationId $customId
            $result.CorrelationId | Should-Be $customId
        }
    }

    Context "Analyzer Cleanliness" {
        It "Produces no analyzer warnings or errors, as the file header claims" {
            # The function is documented as the compliant contrast. Before this test
            # existed it carried two warnings - an unused $errorDetails hashtable and
            # a plural noun - so the claim was false and nothing caught it.
            $start = ($script:Functions | Where-Object { $_.Name -eq 'Get-TestResult' }).Extent.StartLineNumber

            $findings = Invoke-ScriptAnalyzer -Path $script:SourcePath -Severity Warning, Error |
                Where-Object { $_.Line -ge $start }

            ($findings | ForEach-Object { "$($_.RuleName) L$($_.Line)" }) -join '; ' | Should-Be ''
        }
    }
}

Describe "Process-TestData Function" -Tag "Unit", "QualityIssue" {

    Context "Verb Validation" {
        It "Uses a verb PowerShell does not approve, which is the demonstration" {
            $verb = ('Process-TestData' -split '-', 2)[0]
            (Get-Verb).Verb | Should-All { $_ -ne $verb }
        }
    }

    Context "Basic Functionality" {
        It "Should process simple data" {
            $result = Process-TestData -Data "test"
            $result | Should-Be "Processed: test"
        }
    }
}

Describe "Deliberate Violations Stay Pinned" -Tag "Integration", "QualityCheck" {

    # These lock the file's stated violations to what it actually contains. The
    # header lists them, Tools/Test-StandardsCompliance.ps1 is expected to catch
    # them, and both CI workflows exclude the file on that basis. If someone
    # cleans one up, these fail and force the header and the exclusion to be
    # revisited rather than silently drifting out of date.

    Context "PowerShell Best Practices" {
        It "Keeps exactly the two Write-Host calls the header describes" {
            $calls = Get-CallsTo -Name 'Write-Host'

            $calls.Count | Should-Be 2
            # Both belong to the non-compliant function, not the compliant one
            $goodStart = ($script:Functions | Where-Object { $_.Name -eq 'Get-TestResult' }).Extent.StartLineNumber
            foreach ($call in $calls) {
                $call.Extent.StartLineNumber | Should-BeLessThan $goodStart
            }
        }

        It "Keeps Process-TestData as the only non-approved verb in the file" {
            $approvedVerbs = (Get-Verb).Verb
            $nonApproved = $script:Functions.Name |
                Where-Object { ($_ -split '-', 2)[0] -notin $approvedVerbs }

            ($nonApproved -join ', ') | Should-Be 'Process-TestData'
        }

        It 'Keeps the $Error[0] catch block that UseDollarUnderscoreInCatch reports' {
            $indexed = $script:Ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.IndexExpressionAst] -and
                    $node.Target.VariablePath.UserPath -eq 'Error'
                }, $true)

            $indexed.Count | Should-Be 1
        }
    }

    Context "The Compliance Checker" {
        It "Reports the three rules the file header says it reports" {
            # This is the file's reason for existing, and the basis on which both
            # CI workflows exclude it from production analysis. The Tools suite
            # proves each rule fires against a synthetic fixture; nothing proved
            # it fires against the file the header points at.
            $checker = Join-Path $PSScriptRoot '..' '..' 'Tools' 'Test-StandardsCompliance.ps1' | Resolve-Path

            $result = & $checker -Path $script:SourcePath -PassThru 6>$null

            foreach ($rule in 'UseApprovedVerbs', 'AvoidPSCustomObjectOutputType', 'UseDollarUnderscoreInCatch') {
                $result.ComplianceIssues.RuleName | Should-ContainCollection $rule
            }
        }
    }

    Context "Security Best Practices" {
        It "Contains no hardcoded passwords" {
            # Unlike the checks above this is not a pinned violation - security
            # issues were removed from this file deliberately, and must stay out.
            $content = Get-Content -Path $script:SourcePath -Raw

            $passwordPatterns = @(
                'password\s*[:=]\s*["\x27]\w{3,}["\x27]',
                '\$\w*[Pp]assword\w*\s*=\s*["\x27]\w+["\x27]'
            )

            $found = $passwordPatterns | Where-Object { $content -match $_ }

            ($found -join '; ') | Should-Be ''
        }

        It "Contains no interpolated SQL" {
            $content = Get-Content -Path $script:SourcePath -Raw
            $content | Should-NotMatchString 'SELECT .*\$\w+'
        }
    }

    Context "File Encoding" {
        It "Is pure ASCII, so PSUseBOMForUnicodeEncodedFile stays quiet" {
            # The file previously used checkmark emoji in its comments, which made
            # it non-ASCII without a BOM and tripped the rule.
            $content = [System.IO.File]::ReadAllText($script:SourcePath)
            $nonAscii = [regex]::Matches($content, '[^\x00-\x7F]')

            $nonAscii.Count | Should-Be 0
        }
    }
}
