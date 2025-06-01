#Requires -Module Pester

BeforeAll {
    # Import the module containing the function to test
    $ModulePath = Join-Path $PSScriptRoot '..\..\Examples\Basic-Function-Example.ps1'
    . $ModulePath
}

Describe "Get-BasicServerInfo" -Tag "Unit", "Example" {
    
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
        
        It "Should reject invalid computer names: <InvalidName>" -TestCases @(
            @{ InvalidName = 'SERVER_01'; ExpectedError = '*invalid characters*' }
            @{ InvalidName = 'SERVER 01'; ExpectedError = '*invalid characters*' }
            @{ InvalidName = ''; ExpectedError = '*cannot be null or empty*' }
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
        BeforeEach {
            # Mock external dependencies for isolated testing
            Mock Test-Connection { return $true } -ParameterFilter { $ComputerName -eq 'MOCKSERVER' }
            Mock New-CimSession { 
                return [PSCustomObject]@{ ComputerName = 'MOCKSERVER' }
            } -ParameterFilter { $ComputerName -eq 'MOCKSERVER' }
            Mock Remove-CimSession { } -ParameterFilter { $CimSession.ComputerName -eq 'MOCKSERVER' }
            
            Mock Get-CimInstance {
                switch ($ClassName) {
                    'Win32_OperatingSystem' {
                        return [PSCustomObject]@{
                            Caption = 'Microsoft Windows Server 2019'
                            Version = '10.0.17763'
                            ServicePackMajorVersion = 0
                            OSArchitecture = '64-bit'
                            LastBootUpTime = (Get-Date).AddDays(-5)
                        }
                    }
                    'Win32_ComputerSystem' {
                        return [PSCustomObject]@{
                            TotalPhysicalMemory = 17179869184  # 16 GB
                            Manufacturer = 'Dell Inc.'
                            Model = 'PowerEdge R740'
                            Domain = 'contoso.com'
                            Workgroup = $null
                        }
                    }
                    'Win32_Processor' {
                        return [PSCustomObject]@{
                            Name = 'Intel(R) Xeon(R) Gold 6248 CPU @ 2.50GHz'
                            NumberOfCores = 8
                            NumberOfLogicalProcessors = 16
                        }
                    }
                    'Win32_Service' {
                        return @(
                            [PSCustomObject]@{ Name = 'Spooler'; DisplayName = 'Print Spooler'; StartMode = 'Auto'; State = 'Running' },
                            [PSCustomObject]@{ Name = 'Themes'; DisplayName = 'Themes'; StartMode = 'Auto'; State = 'Running' }
                        )
                    }
                }
            } -ParameterFilter { $CimSession.ComputerName -eq 'MOCKSERVER' }
        }
        
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
        It "Should handle connection failures gracefully" {
            Mock Test-Connection { return $false } -ParameterFilter { $ComputerName -eq 'OFFLINE' }
            
            { Get-BasicServerInfo -ComputerName 'OFFLINE' -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
        
        It "Should continue processing other computers when one fails" {
            Mock Test-Connection { 
                if ($ComputerName -eq 'OFFLINE') { return $false }
                return $true
            }
            Mock New-CimSession { 
                if ($ComputerName -eq 'OFFLINE') { throw "Connection failed" }
                return [PSCustomObject]@{ ComputerName = $ComputerName }
            }
            
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