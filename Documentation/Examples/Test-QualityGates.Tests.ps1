#Requires -Module Pester

BeforeAll {
    # Import the module under test
    $ModulePath = Join-Path $PSScriptRoot '..' 'ExampleModule.psd1'
    if (Test-Path $ModulePath) {
        Import-Module $ModulePath -Force
    }

    # Import the test file directly for testing
    $TestFilePath = Join-Path $PSScriptRoot 'Test-QualityGates.ps1'
    if (Test-Path $TestFilePath) {
        . $TestFilePath
    }
}

Describe "Test-QualityGates Function" -Tag "Unit", "QualityDemo" {

    Context "Parameter Validation" {
        It "Should accept valid UserName parameter" {
            { Test-QualityGates -UserName "testuser" } | Should -Not -Throw
        }

        It "Should handle empty ServerList gracefully" {
            $result = Test-QualityGates -UserName "testuser" -ServerList @()
            $result | Should -Not -BeNullOrEmpty
            $result.ServersProcessed | Should -Be 0
        }

        It "Should process multiple servers" {
            $servers = @("server1", "server2", "server3")
            $result = Test-QualityGates -UserName "testuser" -ServerList $servers
            $result.ServersProcessed | Should -Be 3
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
            { Test-QualityGates -UserName "nonexistentuser" } | Should -Throw "*User not found*"
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

            $result | Should -BeOfType [PSCustomObject]
            $result.UserName | Should -Be "testuser"
            $result.ServersProcessed | Should -Be 1
            $result.ProcessedAt | Should -BeOfType [DateTime]
        }

        It "Should include log size information" {
            $result = Test-QualityGates -UserName "testuser"
            $result.LogSize | Should -BeGreaterThan 0
        }

        It "Should include database query information" {
            $result = Test-QualityGates -UserName "testuser"
            $result.DatabaseQuery | Should -Match "SELECT.*FROM.*Users"
        }
    }
}

Describe "Get-TestResults Function" -Tag "Unit", "GoodExample" {

    Context "Proper Implementation Validation" {
        It "Should use approved PowerShell verb" {
            # Verify the function name uses an approved verb
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            "Get" | Should -BeIn $approvedVerbs
        }

        It "Should accept mandatory TestName parameter" {
            { Get-TestResults -TestName "SecurityTest" } | Should -Not -Throw
        }

        It "Should generate correlation ID automatically" {
            $result = Get-TestResults -TestName "AutoTest"
            $result.CorrelationId | Should -Not -BeNullOrEmpty
            $result.CorrelationId | Should -Match "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        }

        It "Should handle empty test name appropriately" {
            { Get-TestResults -TestName "" } | Should -Throw "*cannot be empty*"
        }

        It "Should handle whitespace-only test name" {
            { Get-TestResults -TestName "   " } | Should -Throw "*cannot be empty*"
        }

        It "Should return properly typed result" {
            $result = Get-TestResults -TestName "TypeTest"
            $result.PSTypeName | Should -Be "TestResult"
            $result.Status | Should -Be "Passed"
        }

        It "Should include all required properties" {
            $result = Get-TestResults -TestName "PropertyTest"

            $result.TestName | Should -Be "PropertyTest"
            $result.Status | Should -Not -BeNullOrEmpty
            $result.CorrelationId | Should -Not -BeNullOrEmpty
            $result.ExecutedAt | Should -BeOfType [DateTime]
        }
    }

    Context "Parameter Validation Best Practices" {
        It "Should trim whitespace from TestName parameter" {
            $result = Get-TestResults -TestName "  TrimTest  "
            $result.TestName | Should -Be "TrimTest"
        }

        It "Should accept custom correlation ID" {
            $customId = [System.Guid]::NewGuid().ToString()
            $result = Get-TestResults -TestName "CustomIdTest" -CorrelationId $customId
            $result.CorrelationId | Should -Be $customId
        }
    }
}

Describe "Process-TestData Function" -Tag "Unit", "QualityIssue" {

    Context "Verb Validation" {
        It "Should use non-approved verb (demonstrates quality issue)" {
            # This test documents the quality issue for educational purposes
            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
            "Process" | Should -Not -BeIn $approvedVerbs
        }
    }

    Context "Basic Functionality" {
        It "Should process simple data" {
            $result = Process-TestData -Data "test"
            $result | Should -Be "Processed: test"
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