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

.PARAMETER PassThru
    Return the results object instead of exiting with a status code. Without it the
    script exits 1 when any issue is found and 0 otherwise, which suits CI but
    prevents a caller from reading the results.

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
    - PSScriptAnalyzer module (1.25.0+)
    - PowerShell 7.6 (LTS) or Windows PowerShell 5.1
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
    [string]$OutputPath,

    [Parameter(HelpMessage = "Return the results object instead of exiting with a status code")]
    [switch]$PassThru
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
                # Install-PSResource is in-box on PowerShell 7.4+; 5.1 falls back to PowerShellGet
                if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
                    Install-PSResource $module -Scope CurrentUser -TrustRepository
                }
                else {
                    Install-Module $module -Scope CurrentUser -Force -SkipPublisherCheck
                }
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
        # Populated with defaults so an early return - no files found - still yields
        # a coherent object. Previously the summary stayed empty and the console
        # printed "Compliance: %".
        Summary = @{
            CompliancePercentage = 0
            OverallStatus        = 'NOT-RUN'
            TotalAnalysisTime    = [TimeSpan]::Zero
            AverageFileSize      = 0
        }
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
            # Match the file name and the Tests directory, never the whole path.
            # Testing $_.FullName meant a project living under any path containing
            # "test" - C:\testing\MyProject - excluded every file and analysed
            # nothing, while still reporting success.
            $psFiles = $psFiles | Where-Object {
                $_.Name -notlike "*.Tests.ps1" -and
                $_.FullName -notlike "*$([IO.Path]::DirectorySeparatorChar)Tests$([IO.Path]::DirectorySeparatorChar)*"
            }
        }
        
        $results.TotalFiles = $psFiles.Count
        Write-Information "Found $($psFiles.Count) PowerShell files to analyze" -InformationAction Continue
        
        if ($psFiles.Count -eq 0) {
            # Do not emit $results here - the end block owns the single return, and
            # emitting from both produced two objects on the pipeline.
            Write-Warning "No PowerShell files found to analyze"
            return
        }
        
        # Progress tracking
        $currentFile = 0
        
        foreach ($file in $psFiles) {
            $currentFile++
            $percentComplete = [math]::Round(($currentFile / $psFiles.Count) * 100, 1)
            
            Write-Progress -Activity "Analyzing PowerShell Files" -Status "Processing $($file.Name)" -PercentComplete $percentComplete
            Write-Verbose "Analyzing: $($file.Name) ($currentFile/$($psFiles.Count))"
            
            # $fileResult must exist before the analysis runs. Previously the whole
            # analysis lived inside this hashtable's initializer, assigned to
            # AnalysisTime, and mutated $fileResult.Issues while $fileResult was
            # still being constructed - so the first file threw "property 'Issues'
            # cannot be found" and later files mutated the *previous* file's result.
            $fileResult = @{
                FileName = $file.Name
                FilePath = $file.FullName
                RelativePath = $file.FullName.Replace($results.AnalyzedPath, "").TrimStart('\', '/')
                FileSize = $file.Length
                Issues = @()
                Passed = $true
                AnalysisTime = [TimeSpan]::Zero
            }

            $fileResult.AnalysisTime = Measure-Command {

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

                        # Anti-pattern rules run against code with comments and string
                        # literals blanked out. Matching raw text flagged every file
                        # that *documents* an anti-pattern - including this script,
                        # whose rule table names the patterns it looks for, and the
                        # examples whose comments explain what not to do.
                        $codeOnly = $content
                        $tokens = $null
                        $null = [System.Management.Automation.Language.Parser]::ParseInput(
                            $content, [ref]$tokens, [ref]$null)
                        if ($tokens) {
                            $sb = [System.Text.StringBuilder]::new($content)
                            foreach ($tok in ($tokens | Where-Object {
                                    $_.Kind -eq 'Comment' -or $_.Kind -eq 'StringLiteral' -or $_.Kind -eq 'StringExpandable'
                                })) {
                                $start = $tok.Extent.StartOffset
                                $len = $tok.Extent.EndOffset - $start
                                if ($len -gt 0 -and ($start + $len) -le $sb.Length) {
                                    $replacement = (($tok.Extent.Text -replace '[^\r\n]', ' '))
                                    $null = $sb.Remove($start, $len).Insert($start, $replacement)
                                }
                            }
                            $codeOnly = $sb.ToString()
                        }
                        
                        # Check for approved verbs on EVERY function.
                        # -match returns only the first match in a multi-line string,
                        # so the previous form inspected the first function and
                        # ignored the rest: a file whose first function used an
                        # approved verb passed however many later ones did not.
                        $approvedVerbs = Get-Verb | Select-Object -ExpandProperty Verb
                        foreach ($m in [regex]::Matches($codeOnly, '(?im)^\s*function\s+([^-\s]+)-(\S+)')) {
                            $verb = $m.Groups[1].Value
                            if ($verb -notin $approvedVerbs) {
                                $line = ($content.Substring(0, $m.Index) -split "`n").Count
                                $complianceIssue = [PSCustomObject]@{
                                    RuleName = 'UseApprovedVerbs'
                                    Severity = 'Error'
                                    ScriptName = $file.Name
                                    Line = $line
                                    Column = 0
                                    Message = "Function uses non-approved verb: $verb ($verb-$($m.Groups[2].Value))"
                                    ScriptPath = $file.FullName
                                }
                                $fileResult.Issues += $complianceIssue
                                $results.ComplianceIssues += $complianceIssue
                                $results.CriticalIssues++
                                $fileResult.Passed = $false
                            }
                        }

                        # Anti-patterns copilot-instructions.md names explicitly but
                        # nothing enforced. Each maps to a line in "Anti-Patterns to
                        # Avoid" or "Modern PowerShell Features".
                        $antiPatterns = @{
                            'UseDollarUnderscoreInCatch' = @{
                                Pattern  = '(?s)catch\s*\{[^}]*\$Error\[0\]'
                                Message  = 'Uses $Error[0] in a catch block; use $_ instead'
                                Severity = 'Error'
                            }
                            'AvoidPSCustomObjectOutputType' = @{
                                Pattern  = '\[OutputType\(\[PSCustomObject\]\)\]'
                                Message  = 'Misleading [OutputType([PSCustomObject])]; name the type instead'
                                Severity = 'Error'
                            }
                            'UseModernCredentialCreation' = @{
                                Pattern  = 'New-Object\s+(-TypeName\s+)?(System\.Management\.Automation\.)?PSCredential'
                                Message  = 'Uses New-Object for a credential; use [PSCredential]::new()'
                                Severity = 'Warning'
                            }
                        }

                        foreach ($rule in $antiPatterns.GetEnumerator()) {
                            if ($codeOnly -match $rule.Value.Pattern) {
                                $complianceIssue = [PSCustomObject]@{
                                    RuleName   = $rule.Key
                                    Severity   = $rule.Value.Severity
                                    ScriptName = $file.Name
                                    Line       = 0
                                    Column     = 0
                                    Message    = $rule.Value.Message
                                    ScriptPath = $file.FullName
                                }
                                $fileResult.Issues += $complianceIssue
                                $results.ComplianceIssues += $complianceIssue
                                if ($rule.Value.Severity -eq 'Error') { $results.CriticalIssues++ } else { $results.HighIssues++ }
                                $fileResult.Passed = $false
                            }
                        }

                        # #requires is itself a comment, so this runs against raw
                        # content rather than $codeOnly.
                        if ($content -match '(?im)^\s*#requires\s+-Version\s+(6\.\d+|7\.[0-3])\b') {
                            $complianceIssue = [PSCustomObject]@{
                                RuleName   = 'AvoidRetiredVersionRequires'
                                Severity   = 'Warning'
                                ScriptName = $file.Name
                                Line       = 0
                                Column     = 0
                                Message    = 'Targets a retired PowerShell version; 7.4 is the lowest supported floor'
                                ScriptPath = $file.FullName
                            }
                            $fileResult.Issues += $complianceIssue
                            $results.ComplianceIssues += $complianceIssue
                            $results.HighIssues++
                            $fileResult.Passed = $false
                        }

                        # Comment-based help that opens with # instead of <# is
                        # silently ignored by Get-Help, so the function ships with no
                        # discoverable help at all.
                        if ($content -match '(?m)^\s*#\s*\.(SYNOPSIS|DESCRIPTION)\b') {
                            $complianceIssue = [PSCustomObject]@{
                                RuleName   = 'UseBlockCommentBasedHelp'
                                Severity   = 'Error'
                                ScriptName = $file.Name
                                Line       = 0
                                Column     = 0
                                Message    = 'Comment-based help uses # rather than a <# ... #> block; Get-Help will not see it'
                                ScriptPath = $file.FullName
                            }
                            $fileResult.Issues += $complianceIssue
                            $results.ComplianceIssues += $complianceIssue
                            $results.CriticalIssues++
                            $fileResult.Passed = $false
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
                        # PowerShell 7.5 optimized `+=` on object arrays - it now outperforms
                        # List<T>.Add(). Only flag this when the file declares a target that
                        # still pays the O(n^2) cost (Windows PowerShell 5.1 or PowerShell 7.4).
                        $targetsLegacyArrayAppend = $true
                        if ($content -match '(?im)^\s*#requires\s+-Version\s+(\d+\.\d+)') {
                            $targetsLegacyArrayAppend = [version]$Matches[1] -lt [version]'7.5'
                        }

                        if ($targetsLegacyArrayAppend -and $content -match '\$\w+\s*\+=\s*.*\$\w+') {
                            $perfIssue = [PSCustomObject]@{
                                Type = 'ArrayAppending'
                                File = $file.Name
                                FilePath = $file.FullName
                                Message = 'Array appending detected in a file targeting PowerShell 5.1/7.4, where += is O(n^2)'
                                Severity = 'Medium'
                                Recommendation = 'Assign the loop output directly ($x = foreach (...) { ... }), or use [System.Collections.Generic.List[object]]. Not ArrayList. On PowerShell 7.5+, += is no longer a performance defect.'
                            }
                            $results.PerformanceIssues += $perfIssue
                            $fileResult.Issues += $perfIssue
                            $results.MediumIssues++
                        }

                        # ArrayList is a non-generic .NET 1.1 type - flag on every version
                        if ($content -match '\[System\.Collections\.ArrayList\]|New-Object\s+System\.Collections\.ArrayList') {
                            $arrayListIssue = [PSCustomObject]@{
                                Type = 'LegacyCollectionType'
                                File = $file.Name
                                FilePath = $file.FullName
                                Message = 'ArrayList used instead of a generic collection'
                                Severity = 'Low'
                                Recommendation = 'Use [System.Collections.Generic.List[object]] or a typed List[T]. ArrayList boxes values and forces [void] on every Add().'
                            }
                            $results.PerformanceIssues += $arrayListIssue
                            $fileResult.Issues += $arrayListIssue
                            $results.LowIssues++
                        }
                    }
                }

            $results.FileResults += $fileResult
            
            if ($fileResult.Passed) {
                $results.PassedFiles++
                if ($Detailed) {
                    Write-Information "[PASS] $($file.Name)" -InformationAction Continue
                }
            } else {
                $results.FailedFiles++
                if ($Detailed) {
                    Write-Information "[FAIL] $($file.Name) - $($fileResult.Issues.Count) issues" -InformationAction Continue
                }
            }
        }
        
        Write-Progress -Activity "Analyzing PowerShell Files" -Completed
        
        # Calculate summary
        $results.TotalIssues = $results.CriticalIssues + $results.HighIssues + $results.MediumIssues + $results.LowIssues
        $results.Summary = @{
            CompliancePercentage = if ($results.TotalFiles -gt 0) { [math]::Round(($results.PassedFiles / $results.TotalFiles) * 100, 1) } else { 0 }
            OverallStatus = if ($results.CriticalIssues -eq 0 -and $results.HighIssues -eq 0) { 'PASSED' } elseif ($results.CriticalIssues -eq 0) { 'WARNING' } else { 'FAILED' }
            # Measure-Object -Sum cannot total TimeSpan values ("Input object ... is
            # not numeric"), and $ErrorActionPreference is Stop, so this aborted the
            # whole analysis. Sum the ticks and rebuild the TimeSpan.
            TotalAnalysisTime = [TimeSpan]::FromTicks(
                ($results.FileResults | ForEach-Object { $_.AnalysisTime.Ticks } | Measure-Object -Sum).Sum
            )
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
    }
    elseif ($results.TotalFiles -eq 0) {
        # Analysing nothing is not compliance. Previously this printed the success
        # message and exited 0, so a misconfigured path or an over-broad
        # -ExcludeTests filter looked like a clean pass.
        Write-Warning "No PowerShell files were analysed - nothing has been verified. Check -Path and -ExcludeTests."
    }
    else {
        Write-Information "`nAll $($results.TotalFiles) file(s) meet PowerShell enterprise standards!" -InformationAction Continue
    }

    Write-Verbose "Analysis completed in $([math]::Round($results.Summary.TotalAnalysisTime.TotalSeconds, 2)) seconds"

    # Return the results object for programmatic use. `exit` terminates the whole
    # host, so a caller that wants the data - a test, or another script - cannot
    # use the CLI path. This is why the original `return` below the exits was
    # unreachable.
    if ($PassThru) {
        return $results
    }

    # CLI/CI contract, unchanged when -PassThru is not supplied: non-zero exit
    # when any issue was found.
    if ($results.TotalIssues -gt 0) { exit 1 } else { exit 0 }
}
