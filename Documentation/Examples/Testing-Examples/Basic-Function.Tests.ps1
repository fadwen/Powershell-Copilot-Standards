#Requires -Module Pester

BeforeAll {
    # Import the module containing the function to test
    $ModulePath = Join-Path $PSScriptRoot '..\..\Examples\Basic-Function-Example.ps1'
    . $ModulePath
}

Describe "Get-BasicServerInfo" -Tag "Unit", "Example" {

    # Default mocks live at Describe level so every Context is hermetic - no test
    # reaches a real network. Contexts below override individual mocks as needed.
    #
    # -RemoveParameterType CimSession is required: PowerShell binds parameters using
    # the *original* command's metadata even when a command is mocked, so passing a
    # PSCustomObject stub to -CimSession fails type coercion before the mock body runs.
    BeforeEach {
        Mock Test-Connection { $true }

        Mock New-CimSession { [PSCustomObject]@{ ComputerName = $ComputerName } }

        Mock Remove-CimSession -RemoveParameterType CimSession -MockWith { }

        Mock Get-CimInstance -RemoveParameterType CimSession -MockWith {
            switch ($ClassName) {
                'Win32_OperatingSystem' {
                    [PSCustomObject]@{
                        Caption                 = 'Microsoft Windows Server 2019'
                        Version                 = '10.0.17763'
                        ServicePackMajorVersion = 0
                        OSArchitecture          = '64-bit'
                        LastBootUpTime          = (Get-Date).AddDays(-5)
                    }
                }
                'Win32_ComputerSystem' {
                    [PSCustomObject]@{
                        TotalPhysicalMemory = 17179869184  # 16 GB
                        Manufacturer        = 'Dell Inc.'
                        Model               = 'PowerEdge R740'
                        Domain              = 'contoso.com'
                        Workgroup           = $null
                    }
                }
                'Win32_Processor' {
                    [PSCustomObject]@{
                        Name                      = 'Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz'
                        NumberOfCores             = 8
                        NumberOfLogicalProcessors = 16
                    }
                }
                'Win32_Service' {
                    @(
                        [PSCustomObject]@{ Name = 'Spooler'; DisplayName = 'Print Spooler'; StartMode = 'Auto'; State = 'Running' }
                        [PSCustomObject]@{ Name = 'Themes'; DisplayName = 'Themes'; StartMode = 'Auto'; State = 'Running' }
                    )
                }
            }
        }
    }

    Context "Parameter Validation" {
        It "Should accept valid computer names: <TestCase>" -TestCases @(
            @{ ComputerName = 'SERVER01'; Expected = $true }
            @{ ComputerName = 'web01.contoso.com'; Expected = $true }
            @{ ComputerName = 'DB-SERVER-01'; Expected = $true }
        ) {
            param($ComputerName, $Expected)
            
            # This should not throw
            { Get-BasicServerInfo -ComputerName $ComputerName -WhatIf } | Should -Not -Throw
        }
        
        # Expected messages are the ones PowerShell's validation attributes actually
        # emit. ValidatePattern/ValidateLength do not produce friendly text; asserting
        # invented wording here is what let these tests rot unnoticed.
        It "Should reject invalid computer names: <InvalidName>" -TestCases @(
            @{ InvalidName = 'SERVER_01'; ExpectedError = '*does not match the*pattern*' }
            @{ InvalidName = 'SERVER 01'; ExpectedError = '*does not match the*pattern*' }
            @{ InvalidName = ''; ExpectedError = '*length*is too short*' }
        ) {
            param($InvalidName, $ExpectedError)
            
            { Get-BasicServerInfo -ComputerName $InvalidName } | Should -Throw $ExpectedError
        }
        
        It "Should support pipeline input" {
            $computerNames = @('SERVER01', 'SERVER02')
            
            # This should not throw and should accept pipeline input
            { $computerNames | Get-BasicServerInfo -WhatIf } | Should -Not -Throw
        }
    }
    
    Context "Core Functionality" {

        It "Should return expected object structure" {
            $result = Get-BasicServerInfo -ComputerName 'MOCKSERVER'
            
            # Verify object structure
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [PSCustomObject]
            
            # Verify required properties
            $result.ComputerName | Should -Be 'MOCKSERVER'
            $result.OperatingSystem | Should -Be 'Microsoft Windows Server 2019'
            $result.TotalMemoryGB | Should -Be 16
            $result.CorrelationId | Should -Not -BeNullOrEmpty
        }
        
        It "Should include services when IncludeServices switch is used" {
            $result = Get-BasicServerInfo -ComputerName 'MOCKSERVER' -IncludeServices
            
            $result.RunningServices | Should -Not -BeNullOrEmpty
            $result.RunningServiceCount | Should -Be 2
            $result.RunningServices[0].Name | Should -Be 'Spooler'
        }
        
        It "Should calculate uptime correctly" {
            $result = Get-BasicServerInfo -ComputerName 'MOCKSERVER'
            
            $result.UptimeDays | Should -BeGreaterThan 4.9
            $result.UptimeDays | Should -BeLessThan 5.1
        }
    }
    
    Context "Error Handling" {

        # NOTE: PowerShell 7 renamed Test-Connection's -ComputerName parameter to
        # -TargetName, keeping ComputerName only as an alias. Pester binds mock
        # variables by the *real* parameter name, so a filter written against
        # $ComputerName never matches and the mock silently does nothing. Use
        # $TargetName here.
        #
        # These overrides also live in BeforeEach rather than inside It, because a
        # mock declared inside It does not reliably apply to a function that was
        # dot-sourced in BeforeAll.
        BeforeEach {
            Mock Test-Connection {
                if ($TargetName -eq 'OFFLINE') { return $false }
                return $true
            }
            Mock New-CimSession {
                if ($ComputerName -eq 'OFFLINE') { throw "Connection failed" }
                [PSCustomObject]@{ ComputerName = $ComputerName }
            }
        }

        It "Should handle connection failures gracefully" {
            { Get-BasicServerInfo -ComputerName 'OFFLINE' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }

        It "Should continue processing other computers when one fails" {
            $results = Get-BasicServerInfo -ComputerName @('MOCKSERVER', 'OFFLINE') -ErrorAction SilentlyContinue

            # Should get one successful result despite one failure
            $results | Should -Not -BeNullOrEmpty
            $results.ComputerName | Should -Contain 'MOCKSERVER'
        }
    }
    
    Context "Performance Requirements" {
        It "Should complete within acceptable time limits" {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            Get-BasicServerInfo -ComputerName 'MOCKSERVER' | Out-Null
            
            $stopwatch.Stop()
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # 5 seconds max for mocked operations
        }
        
        It "Should include performance metrics in output" {
            $result = Get-BasicServerInfo -ComputerName 'MOCKSERVER'
            
            $result.QueryTime | Should -Not -BeNullOrEmpty
            $result.QueryDurationMs | Should -BeGreaterThan 0
            $result.CorrelationId | Should -Not -BeNullOrEmpty
        }
    }
}