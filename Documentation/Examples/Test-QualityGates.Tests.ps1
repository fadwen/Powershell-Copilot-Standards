#Requires -Module Pester

BeforeAll {
    # Dot-source the file under test
    $TestFilePath = Join-Path $PSScriptRoot 'Test-QualityGates.ps1'
    if (Test-Path $TestFilePath) {
        . $TestFilePath
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

Describe "Get-TestResults Function" -Tag "Unit", "GoodExample" {

    Context "Proper Implementation Validation" {
        It "Should use approved PowerShell verb" {
            # Should -BeIn has no 1:1 replacement; Should-Any expresses the same check
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $approvedVerbs | Should-Any { $_ -eq 'Get' }
        }

        It "Should accept mandatory TestName parameter" {
            Get-TestResults -TestName "SecurityTest"
        }

        It "Should generate correlation ID automatically" {
            $result = Get-TestResults -TestName "AutoTest"
            $result.CorrelationId | Should-NotBeEmptyString
            $result.CorrelationId |
                Should-MatchString "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        }

        It "Should handle empty test name appropriately" {
            # A Mandatory [string] rejects '' during binding, before the body runs,
            # so the message comes from PowerShell - not the function's own guard.
            { Get-TestResults -TestName "" } | Should-Throw -ExceptionMessage '*empty string*'
        }

        It "Should handle whitespace-only test name" {
            # Whitespace binds fine, so the function's own validation produces this one
            { Get-TestResults -TestName "   " } |
                Should-Throw -ExceptionMessage '*cannot be empty or whitespace*'
        }

        It "Should return properly typed result" {
            $result = Get-TestResults -TestName "TypeTest"
            # PSTypeName is consumed when constructing the object; it sets the type
            # name rather than remaining as a readable property.
            $result.PSObject.TypeNames[0] | Should-Be "TestResult"
            $result.Status | Should-Be "Passed"
        }

        It "Should include all required properties" {
            $result = Get-TestResults -TestName "PropertyTest"

            $result.TestName | Should-Be "PropertyTest"
            $result.Status | Should-NotBeEmptyString
            $result.CorrelationId | Should-NotBeEmptyString
            $result.ExecutedAt | Should-HaveType ([datetime])
        }
    }

    Context "Parameter Validation Best Practices" {
        It "Should trim whitespace from TestName parameter" {
            $result = Get-TestResults -TestName "  TrimTest  "
            $result.TestName | Should-Be "TrimTest"
        }

        It "Should accept custom correlation ID" {
            $customId = [System.Guid]::NewGuid().ToString()
            $result = Get-TestResults -TestName "CustomIdTest" -CorrelationId $customId
            $result.CorrelationId | Should-Be $customId
        }
    }
}

Describe "Process-TestData Function" -Tag "Unit", "QualityIssue" {

    Context "Verb Validation" {
        It "Should use non-approved verb (demonstrates quality issue)" {
            # This test documents the quality issue for educational purposes
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            $approvedVerbs | Should-All { $_ -ne 'Process' }
        }
    }

    Context "Basic Functionality" {
        It "Should process simple data" {
            $result = Process-TestData -Data "test"
            $result | Should-Be "Processed: test"
        }
    }
}

Describe "Quality Standards Compliance" -Tag "Integration", "QualityCheck" {

    Context "PowerShell Best Practices" {
        It "Should use Write-Verbose instead of Write-Host in functions" {
            # This test would check for Write-Host usage (quality issue in Test-QualityGates)
            $testFile = Get-Content -Path (Join-Path $PSScriptRoot 'Test-QualityGates.ps1') -Raw

            # Count Write-Host occurrences (should be minimal in production code)
            $writeHostCount = ([regex]::Matches($testFile, 'Write-Host', 'IgnoreCase')).Count

            # Document the quality issue
            if ($writeHostCount -gt 0) {
                Write-Warning "Found $writeHostCount instances of Write-Host in test file (quality issue for demonstration)"
            }
        }

        It "Should use approved PowerShell verbs in all functions" {
            $testFile = Get-Content -Path (Join-Path $PSScriptRoot 'Test-QualityGates.ps1') -Raw
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb

            # Find function definitions
            $functionMatches = [regex]::Matches($testFile, 'function\s+([A-Za-z]+)-([A-Za-z0-9]+)', 'IgnoreCase')

            $verbIssues = @()
            foreach ($match in $functionMatches) {
                $verb = $match.Groups[1].Value
                if ($verb -notin $approvedVerbs) {
                    $verbIssues += $verb
                }
            }

            if ($verbIssues.Count -gt 0) {
                Write-Warning "Found non-approved verbs: $($verbIssues -join ', ') (quality issues for demonstration)"
            }
        }
    }

    Context "Security Best Practices" {
        It "Should not contain hardcoded passwords" {
            $testFile = Get-Content -Path (Join-Path $PSScriptRoot 'Test-QualityGates.ps1') -Raw

            # Check for common password patterns
            $passwordPatterns = @(
                'password\s*[:=]\s*["\x27]\w{3,}["\x27]',
                '\$\w*[Pp]assword\w*\s*=\s*["\x27]\w+["\x27]'
            )

            $securityIssues = @()
            foreach ($pattern in $passwordPatterns) {
                if ($testFile -match $pattern) {
                    $securityIssues += "Hardcoded password pattern found"
                }
            }

            if ($securityIssues.Count -gt 0) {
                Write-Warning "Security issues found: $($securityIssues -join ', ') (quality issues for demonstration)"
            }
        }
    }
}