# Test Execution Guide

## Comprehensive Test Runner Script

Create a standardized test execution script for consistent testing across environments:

```powershell
# Invoke-Tests.ps1
[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'Performance', 'Security', 'All')]
    [string]$TestType = 'All',

    [ValidateSet('Development', 'CI', 'Production')]
    [string]$Environment = 'Development',

    [string]$OutputPath = './Tests/Results',
    [switch]$CodeCoverage,
    [switch]$PassThru,
    [switch]$ShowReport,
    [string[]]$Tag = @(),
    [string[]]$ExcludeTag = @(),
    [int]$ThrottleLimit = 5
)

begin {
    Write-Host "🧪 PowerShell Test Execution Framework" -ForegroundColor Cyan
    Write-Host "Test Type: $TestType | Environment: $Environment" -ForegroundColor Green

    # Ensure Pester module is available
    if (-not (Get-Module Pester -ListAvailable | Where-Object Version -ge '5.0')) {
        Write-Error "Pester 5.0+ is required. Install with: Install-Module Pester -Force"
        exit 1
    }

    # Ensure output directory exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # Import test configuration
    $configPath = Join-Path $PSScriptRoot "PesterConfiguration.$Environment.psd1"
    if (-not (Test-Path $configPath)) {
        $configPath = Join-Path $PSScriptRoot "PesterConfiguration.psd1"
    }

    if (Test-Path $configPath) {
        $configData = Import-PowerShellDataFile $configPath
        $config = New-PesterConfiguration -Hashtable $configData
    } else {
        $config = New-PesterConfiguration
    }
}

process {
    try {
        # Configure test execution based on type
        switch ($TestType) {
            'Unit' {
                $config.Run.Path = @('./Tests/Unit')
                $config.Filter.Tag = @('Unit')
                Write-Host "📋 Executing Unit Tests..." -ForegroundColor Yellow
            }
            'Integration' {
                $config.Run.Path = @('./Tests/Integration')
                $config.Filter.Tag = @('Integration')
                Write-Host "🔗 Executing Integration Tests..." -ForegroundColor Yellow
            }
            'Performance' {
                $config.Run.Path = @('./Tests/Performance')
                $config.Filter.Tag = @('Performance')
                Write-Host "⚡ Executing Performance Tests..." -ForegroundColor Yellow
            }
            'Security' {
                $config.Run.Path = @('./Tests/Security')
                $config.Filter.Tag = @('Security')
                Write-Host "🔒 Executing Security Tests..." -ForegroundColor Yellow
            }
            'All' {
                $config.Run.Path = @('./Tests/Unit', './Tests/Integration', './Tests/Performance', './Tests/Security')
                Write-Host "🎯 Executing All Tests..." -ForegroundColor Yellow
            }
        }

        # Apply additional tag filtering
        if ($Tag) {
            $config.Filter.Tag = $config.Filter.Tag + $Tag
        }
        if ($ExcludeTag) {
            $config.Filter.ExcludeTag = $ExcludeTag
        }

        # Configure code coverage
        if ($CodeCoverage) {
            $config.CodeCoverage.Enabled = $true
            $config.CodeCoverage.OutputPath = Join-Path $OutputPath "Coverage-$TestType-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"
            Write-Host "📊 Code coverage enabled" -ForegroundColor Green
        }

        # Configure test results output
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = Join-Path $OutputPath "TestResults-$TestType-$(Get-Date -Format 'yyyyMMdd-HHmmss').xml"

        # Set environment-specific verbosity
        if ($Environment -eq 'CI') {
            $config.Output.Verbosity = 'Normal'
            $config.Output.CIFormat = 'Auto'
        } else {
            $config.Output.Verbosity = 'Detailed'
        }

        # Execute tests
        $startTime = Get-Date
        Write-Host "⏱️  Test execution started at $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray

        $result = Invoke-Pester -Configuration $config

        $endTime = Get-Date
        $duration = $endTime - $startTime

        # Generate comprehensive summary
        Write-Host "`n📊 Test Execution Summary:" -ForegroundColor Green
        Write-Host "  Environment: $Environment" -ForegroundColor Gray
        Write-Host "  Test Type: $TestType" -ForegroundColor Gray
        Write-Host "  Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        Write-Host "  Total Tests: $($result.TotalCount)" -ForegroundColor White
        Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
        Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Yellow
        Write-Host "  Not Run: $($result.NotRunCount)" -ForegroundColor Gray

        # Code coverage summary
        if ($CodeCoverage -and $result.CodeCoverage) {
            $coveragePercent = [math]::Round($result.CodeCoverage.CoveredPercent, 2)
            $coverageColor = if ($coveragePercent -ge 80) { 'Green' } elseif ($coveragePercent -ge 60) { 'Yellow' } else { 'Red' }
            Write-Host "  Code Coverage: $coveragePercent%" -ForegroundColor $coverageColor
            Write-Host "    Lines Covered: $($result.CodeCoverage.NumberOfCommandsExecuted)" -ForegroundColor Gray
            Write-Host "    Total Lines: $($result.CodeCoverage.NumberOfCommandsAnalyzed)" -ForegroundColor Gray
        }

        # Performance summary for performance tests
        if ($TestType -eq 'Performance' -or $TestType -eq 'All') {
            Write-Host "`n⚡ Performance Summary:" -ForegroundColor Cyan
            $performanceTests = $result.Tests | Where-Object { $_.Tag -contains 'Performance' }
            if ($performanceTests) {
                $avgExecutionTime = ($performanceTests | Measure-Object -Property Duration -Average).Average
                Write-Host "  Average Test Duration: $([math]::Round($avgExecutionTime, 2))ms" -ForegroundColor Gray

                $slowTests = $performanceTests | Where-Object { $_.Duration -gt 5000 } | Sort-Object Duration -Descending
                if ($slowTests) {
                    Write-Host "  ⚠️  Slow Tests (>5s):" -ForegroundColor Yellow
                    $slowTests | ForEach-Object {
                        Write-Host "    - $($_.Name): $([math]::Round($_.Duration/1000, 2))s" -ForegroundColor Yellow
                    }
                }
            }
        }

        # Failed test details
        if ($result.FailedCount -gt 0) {
            Write-Host "`n❌ Failed Tests:" -ForegroundColor Red
            foreach ($test in $result.Tests.Failed) {
                Write-Host "  - $($test.ExpandedPath)" -ForegroundColor Red
                Write-Host "    Error: $($test.ErrorRecord.Exception.Message)" -ForegroundColor Red

                # Include troubleshooting hints
                $troubleshootingHint = Get-TroubleshootingHint -TestName $test.Name -Error $test.ErrorRecord
                if ($troubleshootingHint) {
                    Write-Host "    💡 Hint: $troubleshootingHint" -ForegroundColor Cyan
                }
            }
        }

        # Generate test report
        if ($ShowReport) {
            $reportPath = Join-Path $OutputPath "TestReport-$TestType-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
            New-TestReport -TestResult $result -OutputPath $reportPath -CodeCoverage:$CodeCoverage
            Write-Host "`n📄 Test report generated: $reportPath" -ForegroundColor Green
        }

        # Export metrics for trending
        $metrics = @{
            TestType = $TestType
            Environment = $Environment
            Timestamp = Get-Date
            Duration = $duration.TotalSeconds
            TotalTests = $result.TotalCount
            PassedTests = $result.PassedCount
            FailedTests = $result.FailedCount
            SkippedTests = $result.SkippedCount
            CodeCoverage = if ($result.CodeCoverage) { $result.CodeCoverage.CoveredPercent } else { $null }
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            Platform = $PSVersionTable.Platform
        }

        $metricsPath = Join-Path $OutputPath "TestMetrics-$TestType-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $metrics | ConvertTo-Json | Out-File $metricsPath

        # Handle CI/CD integration
        if ($Environment -eq 'CI') {
            # Set GitHub Actions outputs
            if ($env:GITHUB_ACTIONS) {
                Write-Host "::set-output name=total-tests::$($result.TotalCount)"
                Write-Host "::set-output name=passed-tests::$($result.PassedCount)"
                Write-Host "::set-output name=failed-tests::$($result.FailedCount)"
                if ($result.CodeCoverage) {
                    Write-Host "::set-output name=code-coverage::$($result.CodeCoverage.CoveredPercent)"
                }
            }

            # Set Azure DevOps variables
            if ($env:BUILD_BUILDID) {
                Write-Host "##vso[task.setvariable variable=TotalTests]$($result.TotalCount)"
                Write-Host "##vso[task.setvariable variable=PassedTests]$($result.PassedCount)"
                Write-Host "##vso[task.setvariable variable=FailedTests]$($result.FailedCount)"
                if ($result.CodeCoverage) {
                    Write-Host "##vso[task.setvariable variable=CodeCoverage]$($result.CodeCoverage.CoveredPercent)"
                }
            }
        }

        # Return result for further processing
        if ($PassThru) {
            return $result
        }

        # Exit with appropriate code
        if ($result.FailedCount -gt 0) {
            Write-Host "`n💥 Tests failed. Exiting with code 1." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "`n✅ All tests passed successfully!" -ForegroundColor Green
            exit 0
        }

    }
    catch {
        Write-Host "`n💥 Test execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray

        if ($PassThru) {
            throw
        } else {
            exit 1
        }
    }
}

end {
    # Cleanup
    Write-Host "`n🧹 Cleaning up test environment..." -ForegroundColor Gray
}

# Helper functions
function Get-TroubleshootingHint {
    param(
        [string]$TestName,
        [System.Management.Automation.ErrorRecord]$Error
    )

    $hints = @{
        'Connection' = 'Check network connectivity and firewall settings. See ./Troubleshooting/Connectivity/'
        'Authentication' = 'Verify credentials and permissions. See ./Troubleshooting/Security/'
        'Permission' = 'Run as administrator or check file permissions. See ./Troubleshooting/Security/'
        'Memory' = 'Increase available memory or optimize code. See ./Troubleshooting/Performance/'
        'Timeout' = 'Increase timeout values or optimize performance. See ./Troubleshooting/Performance/'
    }

    foreach ($keyword in $hints.Keys) {
        if ($Error.Exception.Message -match $keyword -or $TestName -match $keyword) {
            return $hints[$keyword]
        }
    }

    return "Check ./Troubleshooting/ folder for detailed guidance"
}

function New-TestReport {
    param(
        [object]$TestResult,
        [string]$OutputPath,
        [switch]$CodeCoverage
    )

    # Generate HTML test report
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>PowerShell Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .summary { background: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .passed { color: green; }
        .failed { color: red; }
        .skipped { color: orange; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .test-failed { background-color: #ffebee; }
        .test-passed { background-color: #e8f5e8; }
    </style>
</head>
<body>
    <h1>PowerShell Test Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Tests:</strong> $($TestResult.TotalCount)</p>
        <p><strong class="passed">Passed:</strong> $($TestResult.PassedCount)</p>
        <p><strong class="failed">Failed:</strong> $($TestResult.FailedCount)</p>
        <p><strong class="skipped">Skipped:</strong> $($TestResult.SkippedCount)</p>
        <p><strong>Duration:</strong> $($TestResult.Duration)</p>
"@

    if ($CodeCoverage -and $TestResult.CodeCoverage) {
        $html += "<p><strong>Code Coverage:</strong> $([math]::Round($TestResult.CodeCoverage.CoveredPercent, 2))%</p>"
    }

    $html += @"
    </div>
    <h2>Test Results</h2>
    <table>
        <tr>
            <th>Test Name</th>
            <th>Result</th>
            <th>Duration</th>
            <th>Error Message</th>
        </tr>
"@

    foreach ($test in $TestResult.Tests) {
        $resultClass = if ($test.Result -eq 'Passed') { 'test-passed' } elseif ($test.Result -eq 'Failed') { 'test-failed' } else { '' }
        $errorMessage = if ($test.ErrorRecord) { $test.ErrorRecord.Exception.Message } else { '' }

        $html += @"
        <tr class="$resultClass">
            <td>$($test.ExpandedPath)</td>
            <td class="$($test.Result.ToLower())">$($test.Result)</td>
            <td>$([math]::Round($test.Duration, 2))ms</td>
            <td>$($errorMessage)</td>
        </tr>
"@
    }

    $html += @"
    </table>
</body>
</html>
"@

    $html | Out-File $OutputPath -Encoding UTF8
}
```

## Quick Execution Commands

### Development Testing
```powershell
# Quick unit tests
.\Invoke-Tests.ps1 -TestType Unit -Environment Development

# Unit tests with coverage
.\Invoke-Tests.ps1 -TestType Unit -CodeCoverage -ShowReport

# Specific tags
.\Invoke-Tests.ps1 -Tag 'Critical' -ExcludeTag 'Slow'
```

### CI/CD Pipeline Integration
```powershell
# Full CI test suite
.\Invoke-Tests.ps1 -TestType All -Environment CI -CodeCoverage

# Performance testing only
.\Invoke-Tests.ps1 -TestType Performance -Environment CI

# Security validation
.\Invoke-Tests.ps1 -TestType Security -Environment CI
```

### Parallel Test Execution
```powershell
# Run tests in parallel for faster execution
.\Invoke-Tests.ps1 -TestType All -ThrottleLimit 10
```

## Test Execution Best Practices

### Pre-Test Validation
```powershell
# Validate environment before testing
function Test-TestEnvironment {
    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.0+ required"
    }

    # Check required modules
    $requiredModules = @('Pester')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module $module -ListAvailable)) {
            $issues += "Required module missing: $module"
        }
    }

    # Check test data availability
    if (-not (Test-Path './Tests/TestData')) {
        $issues += "Test data directory missing"
    }

    return @{
        Valid = $issues.Count -eq 0
        Issues = $issues
    }
}
```

### Post-Test Cleanup
```powershell
# Clean up test artifacts
function Clear-TestArtifacts {
    $tempFiles = Get-ChildItem -Path $env:TEMP -Filter "PesterTest*" -Recurse
    $tempFiles | Remove-Item -Force -Recurse

    # Clean up test databases
    if (Test-Path './Tests/TestData/temp.db') {
        Remove-Item './Tests/TestData/temp.db' -Force
    }
}
```

### Test Result Analysis
```powershell
# Analyze test trends
function Get-TestTrends {
    param([string]$ResultsPath = './Tests/Results')

    $metricFiles = Get-ChildItem -Path $ResultsPath -Filter "TestMetrics-*.json"
    $trends = $metricFiles | ForEach-Object {
        Get-Content $_.FullName | ConvertFrom-Json
    } | Sort-Object Timestamp

    return $trends
}
```
