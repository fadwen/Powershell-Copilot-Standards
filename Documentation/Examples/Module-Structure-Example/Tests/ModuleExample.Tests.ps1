#Requires -Module Pester

BeforeAll {
    $script:ManifestPath = Join-Path $PSScriptRoot '..' 'ModuleExample.psd1' | Resolve-Path
    Import-Module $script:ManifestPath -Force
}

AfterAll {
    Remove-Module ModuleExample -Force -ErrorAction SilentlyContinue
}

Describe 'ModuleExample' -Tag 'Unit', 'Example' {

    Context 'Module contract' {

        It 'Has a valid manifest' {
            $manifest = Test-ModuleManifest $script:ManifestPath
            $manifest.Name | Should-Be 'ModuleExample'
            $manifest.PowerShellVersion | Should-Be ([version]'7.6')
        }

        It 'Exports only the public function' {
            (Get-Command -Module ModuleExample).Name | Should-BeCollection @('Get-ExampleData')
        }

        It 'Keeps the private helper internal' {
            # The point of the Public/Private split: the manifest does not export it,
            # so it cannot be called from outside the module.
            Get-Command Connect-ExampleService -ErrorAction SilentlyContinue | Should-BeNull
        }

        It 'Declares a descriptive output type rather than PSCustomObject' {
            (Get-Command Get-ExampleData).OutputType.Name | Should-ContainCollection 'ExampleServiceResult'
        }
    }

    Context 'Get-ExampleData' {

        It 'Returns one result for one service' {
            $result = Get-ExampleData -ServiceName 'Billing'

            $result | Should-NotBeNull
            $result.ServiceName | Should-Be 'Billing'
            $result.Environment | Should-Be 'Development'
        }

        It 'Returns the class type the function declares' {
            $result = Get-ExampleData -ServiceName 'Billing'
            $result.GetType().Name | Should-Be 'ExampleServiceResult'
        }

        It 'Accepts pipeline input and emits one result per service' {
            $results = 'Billing', 'Identity', 'Reporting' | Get-ExampleData

            $results | Should-BeCollection -Count 3
            $results.ServiceName | Should-BeCollection @('Billing', 'Identity', 'Reporting')
        }

        It 'Accepts an array parameter as well as the pipeline' {
            (Get-ExampleData -ServiceName @('Billing', 'Identity')) | Should-BeCollection -Count 2
        }

        It 'Reports Healthy for non-production environments: <Environment>' -TestCases @(
            @{ Environment = 'Development' }
            @{ Environment = 'Test' }
        ) {
            param($Environment)
            (Get-ExampleData -ServiceName 'Billing' -Environment $Environment).Status | Should-Be 'Healthy'
        }

        It 'Reports Degraded for Production' {
            (Get-ExampleData -ServiceName 'Billing' -Environment 'Production').Status | Should-Be 'Degraded'
        }

        It 'Rejects an environment outside the allowed set' {
            { Get-ExampleData -ServiceName 'Billing' -Environment 'Staging' } |
                Should-Throw -ExceptionMessage '*ValidateSet*'
        }

        It 'Requires ServiceName' {
            { Get-ExampleData -ServiceName '' } | Should-Throw
        }

        It 'Generates a correlation id when none is supplied' {
            $result = Get-ExampleData -ServiceName 'Billing'

            $result.CorrelationId | Should-NotBe ([guid]::Empty)
            $result.CorrelationId.ToString() |
                Should-MatchString '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        }

        It 'Uses the supplied correlation id for every service in the batch' {
            $id = [guid]::NewGuid()
            $results = 'Billing', 'Identity' | Get-ExampleData -CorrelationId $id

            # One id per operation, not per item - that is what makes a batch traceable
            $results | Should-All { $_.CorrelationId -eq $id }
        }

        It 'Stamps CheckedAt on each result' {
            $before = Get-Date
            $result = Get-ExampleData -ServiceName 'Billing'

            $result.CheckedAt | Should-HaveType ([datetime])
            $result.CheckedAt | Should-BeGreaterThanOrEqual $before.AddSeconds(-5)
        }
    }

    Context 'Per-item failure handling' {

        It 'Continues the batch when one service fails' {
            InModuleScope ModuleExample {
                Mock Get-ExampleServiceStatus {
                    if ($ServiceName -eq 'Broken') { throw 'service unreachable' }
                    'Healthy'
                }

                $results = 'Billing', 'Broken', 'Identity' |
                    Get-ExampleData -ErrorAction SilentlyContinue

                # The failure must not abort the remaining items
                $results | Should-BeCollection -Count 2
                $results.ServiceName | Should-BeCollection @('Billing', 'Identity')
            }
        }

        It 'Reports the failing service by name and includes the correlation id' {
            InModuleScope ModuleExample {
                Mock Get-ExampleServiceStatus { throw 'service unreachable' }
                $id = [guid]::NewGuid()

                Get-ExampleData -ServiceName 'Broken' -CorrelationId $id `
                    -ErrorAction SilentlyContinue -ErrorVariable err
                $null = $err

                "$err" | Should-MatchString 'Broken'
                "$err" | Should-MatchString ([regex]::Escape($id.ToString()))
            }
        }

        It 'Emits nothing when every service fails' {
            InModuleScope ModuleExample {
                Mock Get-ExampleServiceStatus { throw 'service unreachable' }

                $results = 'A', 'B' | Get-ExampleData -ErrorAction SilentlyContinue
                $results | Should-BeFalsy
            }
        }
    }

    Context 'Module loader' {

        It 'Fails loudly when a source file cannot be dot-sourced' {
            # The loader throws rather than warning: a module that half-loads is
            # worse than one that refuses to.
            # Built under $TestDrive so Pester disposes of it - see test-data-guide.md
            $broken = Join-Path $TestDrive "mse-$([guid]::NewGuid().ToString('N'))"
            foreach ($folder in 'Public', 'Private', 'Classes') {
                New-Item -Path (Join-Path $broken $folder) -ItemType Directory -Force | Out-Null
            }
            Copy-Item (Join-Path $PSScriptRoot '..' 'ModuleExample.psm1') $broken
            Set-Content -Path (Join-Path $broken 'Public\Broken.ps1') -Value 'function Get-Broken { this is not powershell {'

            { Import-Module (Join-Path $broken 'ModuleExample.psm1') -Force -ErrorAction Stop } |
                Should-Throw -ExceptionMessage '*Failed to load public function*'
        }
    }

    Context 'ExampleServiceResult class' {

        It 'Initialises to Unavailable until a status is set' {
            InModuleScope ModuleExample {
                $r = [ExampleServiceResult]::new('Billing', 'Test', [guid]::NewGuid())
                $r.Status | Should-Be 'Unavailable'
            }
        }

        It 'Treats Healthy and Degraded as usable, Unavailable as not' {
            InModuleScope ModuleExample {
                $r = [ExampleServiceResult]::new('Billing', 'Test', [guid]::NewGuid())

                $r.Status = 'Healthy';     $r.IsUsable() | Should-BeTrue
                $r.Status = 'Degraded';    $r.IsUsable() | Should-BeTrue
                $r.Status = 'Unavailable'; $r.IsUsable() | Should-BeFalse
            }
        }

        It 'Rejects a status outside the allowed set' {
            InModuleScope ModuleExample {
                $r = [ExampleServiceResult]::new('Billing', 'Test', [guid]::NewGuid())
                { $r.Status = 'Exploded' } | Should-Throw
            }
        }

        It 'Renders a readable string' {
            InModuleScope ModuleExample {
                $r = [ExampleServiceResult]::new('Billing', 'Test', [guid]::NewGuid())
                $r.Status = 'Healthy'
                $r.ToString() | Should-Be 'Billing [Test]: Healthy'
            }
        }
    }

    Context 'Connect-ExampleService (internal)' {

        It 'Returns a session describing the target environment' {
            InModuleScope ModuleExample {
                $session = Connect-ExampleService -Environment 'Test' -CorrelationId ([guid]::NewGuid())

                $session | Should-HaveType ([hashtable])
                $session.Environment | Should-Be 'Test'
                $session.Endpoint | Should-MatchString 'test$'
            }
        }

        It 'Carries the caller correlation id through' {
            InModuleScope ModuleExample {
                $id = [guid]::NewGuid()
                (Connect-ExampleService -Environment 'Development' -CorrelationId $id).CorrelationId |
                    Should-Be $id
            }
        }

        It 'Rejects an environment outside the allowed set' {
            InModuleScope ModuleExample {
                { Connect-ExampleService -Environment 'Staging' -CorrelationId ([guid]::NewGuid()) } |
                    Should-Throw -ExceptionMessage '*ValidateSet*'
            }
        }
    }
}
