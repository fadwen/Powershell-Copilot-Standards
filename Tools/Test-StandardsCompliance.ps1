# Tools/Test-StandardsCompliance.ps1
<#
.SYNOPSIS
    Tests PowerShell code compliance with enterprise standards

.DESCRIPTION
    Validates PowerShell files against enterprise standards including
    community best practices, security requirements, and style guidelines.
    Provides detailed analysis and actionable recommendations.

.PARAMETER Path
    Path to analyze (file or directory). Defaults to current directory.

.PARAMETER Detailed
    Show detailed analysis results including individual file results

.PARAMETER ExcludeTests
    Exclude test files from analysis (files matching *test*, *Test*, *.Tests.ps1)

.PARAMETER OutputFormat
    Output format for results: Console, JSON, XML, HTML

.PARAMETER OutputPath
    Path to save detailed results (when using JSON, XML, or HTML format)

.EXAMPLE
    .\Test-StandardsCompliance.ps1 -Path "." -Detailed
    
    Analyzes all PowerShell files in current directory with detailed output

.EXAMPLE
    .\Test-StandardsCompliance.ps1 -Path "C:\MyProject" -ExcludeTests -OutputFormat JSON -OutputPath "results.json"
    
    Analyzes project excluding tests and saves results to JSON file

.NOTES
    Author: Jeffrey Stuhr
    Version: 1.0.0
    
    REQUIREMENTS:
    - PSScriptAnalyzer module
    - PowerShell 5.1+ or PowerShell 7.x
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Path to analyze (file or directory)")]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path = ".",
    
    [Parameter(HelpMessage = "Show detailed analysis results")]
    [switch]$Detailed,
    
    [Parameter(HelpMessage = "Exclude test files from analysis")]
    [switch]$ExcludeTests,
    
    [Parameter(HelpMessage = "Output format for results")]
    [ValidateSet('Console', 'JSON', 'XML', 'HTML')]
    [string]$OutputFormat = 'Console',
    
    [Parameter(HelpMessage = "Path to save detailed results")]
    [string]$OutputPath
)

begin {
    $ErrorActionPreference = 'Stop'
    $correlationId = [System.Guid]::NewGuid()
    
    Write-Information "Testing PowerShell Standards Compliance..." -InformationAction Continue
    Write-Verbose "CorrelationId: $correlationId"
    
    # Check for required modules
    $requiredModules = @('PSScriptAnalyzer')
    foreach ($module in $requiredModules) {
        if (-not (Get-Module $module -ListAvailable)) {
            Write-Warning "$module not found. Installing..."
            try {
                Install-Module $module -Scope CurrentUser -Force -SkipPublisherCheck
                Write-Information "Installed $module" -InformationAction Continue
            }
            catch {
                Write-Error "Failed to install $module : $($_.Exception.Message)"
                throw
            }
        }
    }
    
    Import-Module PSScriptAnalyzer -Force
    
    # Initialize results object
    $results = @{
        CorrelationId = $correlationId
        AnalysisDate = Get-Date
        AnalyzedPath = (Resolve-Path $Path).Path
        TotalFiles = 0
        PassedFiles = 0
        FailedFiles = 0
        TotalIssues = 0
        CriticalIssues = 0
        HighIssues = 0
        MediumIssues = 0
        LowIssues = 0
        FileResults = @()
        PSScriptAnalyzerResults = @()
        SecurityIssues = @()
        PerformanceIssues = @()
        ComplianceIssues = @()
        Summary = @{}
    }
}

process {
    try {
        # Get PowerShell files
        $fileFilter = @('*.ps1', '*.psm1', '*.psd1')
        if (Test-Path $Path -PathType Leaf) {
            $psFiles = @(Get-Item $Path)
        } else {
            $psFiles = Get-ChildItem -Path $Path -Include $fileFilter -Recurse | Where-Object { 
                $_.FullName -notlike "*\.git\*" -and 
                $_.FullName -notlike "*\node_modules\*" 
            }
        }
        
        # Exclude test files if requested
        if ($ExcludeTests) {
            $psFiles = $psFiles | Where-Object { 
                $_.FullName -notlike "*test*" -and 
                $_.FullName -notlike "*Test*" -and
                $_.Name -notlike "*.Tests.ps1"
            }
        }
        
        $results.TotalFiles = $psFiles.Count
        Write-Information "Found $($psFiles.Count) PowerShell files to analyze" -InformationAction Continue
        
        if ($psFiles.Count -eq 0) {
            Write-Warning "No PowerShell files found to analyze"
            return $results
        }
        
        # Progress tracking
        $currentFile = 0
        
        foreach ($file in $psFiles) {
            $currentFile++
            $percentComplete = [math]::Round(($currentFile / $psFiles.Count) * 100, 1)
            
            Write-Progress -Activity "Analyzing PowerShell Files" -Status "Processing $($file.Name)" -PercentComplete $percentComplete
            Write-Verbose "Analyzing: $($file.Name) ($currentFile/$($psFiles.Count))"
            
            $fileResult = @{
                FileName = $file.Name
                FilePath = $file.FullName
                RelativePath = $file.FullName.Replace($results.AnalyzedPath, "").TrimStart('\', '/')
                FileSize = $file.Length
                Issues = @()
                Passed = $true
                AnalysisTime = Measure-Command {
                    
                    # PSScriptAnalyzer analysis
                    $fileAnalysisResults = Invoke-ScriptAnalyzer -Path $file.FullName -Severity @('Error', 'Warning', 'Information')
                    
                    if ($fileAnalysisResults) {
                        $fileResult.Issues += $fileAnalysisResults
                        $results.PSScriptAnalyzerResults += $fileAnalysisResults
                        $fileResult.Passed = $false
                        
                        # Categorize issues
                        foreach ($issue in $fileAnalysisResults) {
                            switch ($issue.Severity) {
                                'Error' { $results.CriticalIssues++ }
                                'Warning' { $results.HighIssues++ }
                                'Information' { $results.LowIssues++ }
                            }
                        }
                    }
                    
                    # Community standards check
                    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        
                        # Check for approved verbs
                        if ($content -match 'function\s+([^-\s]+)-') {
                            $verb = $Matches[1]
                            $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
                            if ($verb -notin $approvedVerbs) {
                                $complianceIssue = [PSCustomObject]@{
                                    RuleName = 'UseApprovedVerbs'
                                    Severity = 'Error'
                                    ScriptName = $file.Name
                                    Line = 0
                                    Column = 0
                                    Message = "Function uses non-approved verb: $verb"
                                    ScriptPath = $file.FullName
                                }
                                $fileResult.Issues += $complianceIssue
                                $results.ComplianceIssues += $complianceIssue
                                $results.CriticalIssues++
                                $fileResult.Passed = $false
                            }
                        }
                        
                        # Security checks
                        $securityPatterns = @{
                            'HardcodedPassword' = @{
                                Pattern = 'password\s*[:=]\s*["\x27]\w{3,}["\x27]'
                                Message = 'Potential hardcoded password detected'
                                Severity = 'Critical'
                            }
                            'HardcodedApiKey' = @{
                                Pattern = 'apikey\s*[:=]\s*["\x27]\w{10,}["\x27]'
                                Message = 'Potential hardcoded API key detected'
                                Severity = 'Critical'
                            }
                            'InvokeExpression' = @{
                                Pattern = 'Invoke-Expression|iex\s'
                                Message = 'Use of Invoke-Expression detected (security risk)'
                                Severity = 'High'
                            }
                            'HardcodedSecureString' = @{
                                Pattern = 'ConvertTo-SecureString\s+-String\s+["\x27]'
                                Message = 'Hardcoded SecureString conversion detected'
                                Severity = 'High'
                            }
                        }
                        
                        foreach ($patternInfo in $securityPatterns.GetEnumerator()) {
                            if ($content -match $patternInfo.Value.Pattern) {
                                $securityIssue = [PSCustomObject]@{
                                    Type = $patternInfo.Key
                                    File = $file.Name
                                    FilePath = $file.FullName
                                    Message = $patternInfo.Value.Message
                                    Severity = $patternInfo.Value.Severity
                                    Pattern = $patternInfo.Value.Pattern
                                }
                                $results.SecurityIssues += $securityIssue
                                $fileResult.Issues += $securityIssue
                                $fileResult.Passed = $false
                                
                                if ($patternInfo.Value.Severity -eq 'Critical') {
                                    $results.CriticalIssues++
                                } else {
                                    $results.HighIssues++
                                }
                            }
                        }
                        
                        # Performance checks
                        if ($content -match '\$\w+\s*\+=\s*.*\$\w+') {
                            $perfIssue = [PSCustomObject]@{
                                Type = 'ArrayAppending'
                                File = $file.Name
                                FilePath = $file.FullName
                                Message = 'Potential array appending performance issue detected'
                                Severity = 'Medium'
                                Recommendation = 'Use pipeline output or ArrayList instead of array appending'
                            }
                            $results.PerformanceIssues += $perfIssue
                            $fileResult.Issues += $perfIssue
                            $results.MediumIssues++
                        }
                    }
                }
            }
            
            $results.FileResults += $fileResult
            
            if ($fileResult.Passed) {
                $results.PassedFiles++
                if ($Detailed) {
                    Write-Information "✅ $($file.Name)" -InformationAction Continue
                }
            } else {
                $results.FailedFiles++
                if ($Detailed) {
                    Write-Information "❌ $($file.Name) - $($fileResult.Issues.Count) issues" -InformationAction Continue
                }
            }
        }
        
        Write-Progress -Activity "Analyzing PowerShell Files" -Completed
        
        # Calculate summary
        $results.TotalIssues = $results.CriticalIssues + $results.HighIssues + $results.MediumIssues + $results.LowIssues
        $results.Summary = @{
            CompliancePercentage = if ($results.TotalFiles -gt 0) { [math]::Round(($results.PassedFiles / $results.TotalFiles) * 100, 1) } else { 0 }
            OverallStatus = if ($results.CriticalIssues -eq 0 -and $results.HighIssues -eq 0) { 'PASSED' } elseif ($results.CriticalIssues -eq 0) { 'WARNING' } else { 'FAILED' }
            TotalAnalysisTime = ($results.FileResults | Measure-Object -Property AnalysisTime -Sum).Sum
            AverageFileSize = if ($results.TotalFiles -gt 0) { [math]::Round(($results.FileResults | Measure-Object -Property FileSize -Average).Average / 1KB, 2) } else { 0 }
        }
    }
    catch {
        Write-Error "Analysis failed: $($_.Exception.Message) (CorrelationId: $correlationId)"
        throw
    }
}

end {
    # Display results
    Write-Information "`nCompliance Analysis Summary:" -InformationAction Continue
    Write-Information "  Total Files: $($results.TotalFiles)" -InformationAction Continue
    Write-Information "  Passed: $($results.PassedFiles)" -InformationAction Continue
    Write-Information "  Failed: $($results.FailedFiles)" -InformationAction Continue
    Write-Information "  Compliance: $($results.Summary.CompliancePercentage)%" -InformationAction Continue
    
    if ($results.TotalIssues -gt 0) {
        Write-Information "`nIssues Found:" -InformationAction Continue
        Write-Information "  Critical: $($results.CriticalIssues)" -InformationAction Continue
        Write-Information "  High: $($results.HighIssues)" -InformationAction Continue
        Write-Information "  Medium: $($results.MediumIssues)" -InformationAction Continue
        Write-Information "  Low: $($results.LowIssues)" -InformationAction Continue
    }
    
    # Detailed output if requested
    if ($Detailed -and $results.TotalIssues -gt 0) {
        if ($results.PSScriptAnalyzerResults) {
            Write-Information "`nPSScriptAnalyzer Issues:" -InformationAction Continue
            $results.PSScriptAnalyzerResults | Format-Table RuleName, Severity, ScriptName, Message -AutoSize
        }
        
        if ($results.SecurityIssues) {
            Write-Information "`nSecurity Issues:" -InformationAction Continue
            $results.SecurityIssues | Format-Table Type, File, Message, Severity -AutoSize
        }
        
        if ($results.PerformanceIssues) {
            Write-Information "`nPerformance Issues:" -InformationAction Continue
            $results.PerformanceIssues | Format-Table Type, File, Message, Recommendation -AutoSize
        }
    }
    
    # Output to file if requested
    if ($OutputPath -and $OutputFormat -ne 'Console') {
        try {
            switch ($OutputFormat) {
                'JSON' {
                    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
                    Write-Information "`nResults saved to: $OutputPath" -InformationAction Continue
                }
                'XML' {
                    $results | Export-Clixml -Path $OutputPath
                    Write-Information "`nResults saved to: $OutputPath" -InformationAction Continue
                }
                'HTML' {
                    # Generate HTML report
                    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>PowerShell Standards Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>PowerShell Standards Compliance Report</h1>
        <p>Generated: $($results.AnalysisDate)</p>
        <p>Correlation ID: $($results.CorrelationId)</p>
        <p>Overall Status: <span class="$($results.Summary.OverallStatus.ToLower())">$($results.Summary.OverallStatus)</span></p>
    </div>
    
    <h2>Summary</h2>
    <ul>
        <li>Total Files: $($results.TotalFiles)</li>
        <li>Passed: <span class="passed">$($results.PassedFiles)</span></li>
        <li>Failed: <span class="failed">$($results.FailedFiles)</span></li>
        <li>Compliance: $($results.Summary.CompliancePercentage)%</li>
    </ul>
    
    <h2>Issues Breakdown</h2>
    <ul>
        <li>Critical: <span class="failed">$($results.CriticalIssues)</span></li>
        <li>High: <span class="warning">$($results.HighIssues)</span></li>
        <li>Medium: <span class="warning">$($results.MediumIssues)</span></li>
        <li>Low: $($results.LowIssues)</li>
    </ul>
</body>
</html>
"@
                    $htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8
                    Write-Information "`nHTML report saved to: $OutputPath" -InformationAction Continue
                }
            }
        }
        catch {
            Write-Warning "Failed to save results to file: $($_.Exception.Message)"
        }
    }
    
    # Final recommendations
    if ($results.TotalIssues -gt 0) {
        Write-Information "`nRecommendations:" -InformationAction Continue
        Write-Information "  - Use your Copilot prompts to fix issues:" -InformationAction Continue
        Write-Information "    /security-review for security issues" -InformationAction Continue
        Write-Information "    /optimize-performance for performance issues" -InformationAction Continue
        Write-Information "    /code-analysis for comprehensive analysis" -InformationAction Continue
        Write-Information "    /validate-standards for community standards compliance" -InformationAction Continue
        
        # Exit with error code for CI/CD integration
        exit 1
    } else {
        Write-Information "`nAll files meet PowerShell enterprise standards!" -InformationAction Continue
        exit 0
    }
    
    Write-Verbose "Analysis completed in $([math]::Round($results.Summary.TotalAnalysisTime.TotalSeconds, 2)) seconds"
    
    # Return results object for programmatic use
    return $results
}
