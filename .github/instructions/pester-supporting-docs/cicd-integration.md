# CI/CD Integration Guide

Targets **Pester 6.1+**. Pester 6 supports **Windows PowerShell 5.1** and **PowerShell 7.4+** only -
support for PowerShell 3, 4, 6, and early/unsupported 7.x was removed, so drop `7.2` and `7.3` from
existing test matrices.

**Matrix targets (verified 2026-08-01):** build against **PowerShell 7.6 (LTS)**. PowerShell 7.4 and
7.5 both reach end of support on **10-Nov-2026** - keep them in the matrix only while you still
support consumers on those versions, and plan their removal. See
[powershell-version.instructions.md](../powershell-version.instructions.md).

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Job Design for Pester 6

Two facts shape the pipeline:

1. **Coverage and parallel pull against each other.** Pester 6.0 refused to combine them at all;
   6.1 merges coverage across workers but forces slower breakpoint-based collection to do it. Either
   way, run a fast parallel job without coverage for feedback and a separate sequential job with the
   profiler for the gate.
2. **Discovery failures do not appear in `FailedCount`.** A file that fails discovery contributes
   zero failed tests. Every gate must also check `FailedContainersCount`, and a cheap discovery-only
   job should run first.

```text
validate (discovery-only, fast)
    |
    +--> test-parallel  (no coverage, PS 7.4+, fast feedback)
    +--> test-coverage  (sequential, coverage gate)
    +--> test-ps51      (Windows PowerShell 5.1, sequential - no parallel support)
```

## GitHub Actions Integration

### Complete GitHub Actions Workflow

```yaml
name: PowerShell Testing

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

env:
  POWERSHELL_TELEMETRY_OPTOUT: 1
  PESTER_VERSION: '6.1.0'

jobs:
  # Fast structural check. Catches the Pester 6 breakages - duplicate setup blocks,
  # empty -ForEach, files that cannot be discovered independently - without running
  # a single test.
  validate:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4

    - name: Install Pester
      shell: pwsh
      run: |
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module Pester -MinimumVersion $env:PESTER_VERSION -Force -Scope CurrentUser

    - name: Discovery-only pass
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests'
        $config.Run.SkipRun = $true
        $config.Run.PassThru = $true
        $config.Output.CIFormat = 'GithubActions'

        $result = Invoke-Pester -Configuration $config

        if ($result.FailedContainersCount -gt 0) {
          $result.FailedContainers | ForEach-Object {
            Write-Host "::error file=$($_.Item)::Discovery failed: $($_.ErrorRecord.Exception.Message)"
          }
          throw "$($result.FailedContainersCount) file(s) failed discovery"
        }
        Write-Host "Discovered $($result.TotalCount) tests across $($result.Containers.Count) files"

    - name: Verify every test is tagged
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests'
        $config.Filter.Tag = 'None'   # reserved value: tests with NO tags
        $config.Run.SkipRun = $true
        $config.Run.PassThru = $true
        $config.Output.Verbosity = 'None'

        $result = Invoke-Pester -Configuration $config

        # ShouldRun marks what Filter.Tag selected. TotalCount ignores the filter - it counts
        # everything discovered, so it would fail every non-empty suite - and PassedCount only
        # counts untagged tests that ran AND passed, which under Run.SkipRun is never any.
        $untagged = @($result.Tests | Where-Object ShouldRun)
        if ($untagged.Count -gt 0) {
          $untagged | ForEach-Object {
            Write-Host "::error::Untagged test: $($_.ExpandedPath)"
          }
          throw "$($untagged.Count) test(s) have no tag"
        }

  test:
    needs: validate
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        # Pester 6 supports Windows PowerShell 5.1 and PowerShell 7.4+ only.
        # ubuntu/macos runners ship PowerShell 7.4+; windows-latest has both.
        os: [windows-latest, ubuntu-latest, macos-latest]
        shell: [pwsh]
        include:
          # Windows PowerShell 5.1 - sequential only, no parallel support
          - os: windows-latest
            shell: powershell

    steps:
    - uses: actions/checkout@v4

    - name: Cache PowerShell Modules
      uses: actions/cache@v4
      with:
        path: |
          ~/.local/share/powershell/Modules
          ~/Documents/PowerShell/Modules
          ~/Documents/WindowsPowerShell/Modules
        key: ${{ runner.os }}-pester-${{ env.PESTER_VERSION }}-${{ hashFiles('**/*.psd1') }}
        restore-keys: |
          ${{ runner.os }}-pester-${{ env.PESTER_VERSION }}-

    - name: Install Dependencies
      shell: ${{ matrix.shell }}
      run: |
        # Install-PSResource is in-box on PowerShell 7.4+; Windows PowerShell 5.1 needs PowerShellGet.
        if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
            Install-PSResource Pester -Version "[$env:PESTER_VERSION,)" -Scope CurrentUser -TrustRepository
            Install-PSResource PSScriptAnalyzer -Scope CurrentUser -TrustRepository
        }
        else {
            Set-PSRepository PSGallery -InstallationPolicy Trusted
            Install-Module Pester -MinimumVersion $env:PESTER_VERSION -Force -Scope CurrentUser
            Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
        }

    - name: Run PSScriptAnalyzer
      shell: ${{ matrix.shell }}
      run: |
        $analysisResults = Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
        if ($analysisResults) {
          $analysisResults | Format-Table -AutoSize
          throw "PSScriptAnalyzer found $($analysisResults.Count) issues"
        }

    # Fast feedback: parallel, no coverage. Parallel is silently ignored on
    # Windows PowerShell 5.1, which falls back to sequential with a warning.
    - name: Run Unit Tests
      shell: ${{ matrix.shell }}
      run: |
        Import-Module Pester -MinimumVersion 6.1.0 -Force

        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Unit'
        $config.Run.PassThru = $true
        $config.Run.Parallel = $PSVersionTable.PSVersion.Major -ge 7
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = './TestResults.xml'
        $config.Output.Verbosity = 'Detailed'
        $config.Output.CIFormat = 'GithubActions'

        $result = Invoke-Pester -Configuration $config

        # Check BOTH - a file that fails discovery contributes 0 to FailedCount
        if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
          throw "Unit tests failed: $($result.FailedCount) test failure(s), $($result.FailedContainersCount) container failure(s)"
        }

    - name: Run Integration Tests
      shell: ${{ matrix.shell }}
      run: |
        Import-Module Pester -MinimumVersion 6.1.0 -Force

        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Integration'
        $config.Run.PassThru = $true
        # Integration tests share external resources - never parallel
        $config.Run.Parallel = $false
        $config.Filter.Tag = 'Integration'
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = './IntegrationResults.xml'
        $config.Output.CIFormat = 'GithubActions'

        $result = Invoke-Pester -Configuration $config

        if ($result.FailedCount -gt 0) {
          Write-Warning "Integration tests failed: $($result.FailedCount) failures"
          # Don't fail the build for integration test failures
        }

    - name: Upload Test Results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results-${{ matrix.os }}-${{ matrix.shell }}
        path: |
          TestResults.xml
          IntegrationResults.xml

  # Coverage runs sequentially so it can use the fast profiler tracer. Pester 6.1
  # does support coverage under Run.Parallel, but forces breakpoint mode to do it.
  coverage:
    needs: validate
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4

    - name: Install Pester
      shell: pwsh
      run: |
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module Pester -MinimumVersion $env:PESTER_VERSION -Force -Scope CurrentUser

    - name: Run Tests with Coverage
      shell: pwsh
      run: |
        Import-Module Pester -MinimumVersion 6.1.0 -Force

        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Unit'
        $config.Run.PassThru = $true
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = './Public/*.ps1', './Private/*.ps1'
        # Profiler-based coverage is the v6 default and far faster than breakpoints
        $config.CodeCoverage.UseBreakpoints = $false
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
        $config.CodeCoverage.OutputPath = './coverage.xml'
        # CoveragePercentTarget is the REPORTED target - it does not fail the run.
        # There is no CodeCoverage.Threshold setting.
        $config.CodeCoverage.CoveragePercentTarget = 80
        $config.Output.CIFormat = 'GithubActions'

        $result = Invoke-Pester -Configuration $config

        if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
          throw "Tests failed"
        }

        # Enforce the coverage gate yourself
        $actual = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
        $target = $result.CodeCoverage.CoveragePercentTarget

        "## Code Coverage`n`n**$actual%** (target $target%)" |
          Out-File $env:GITHUB_STEP_SUMMARY -Append

        if ($actual -lt $target) {
          $result.CodeCoverage.CommandsMissed | Group-Object File | ForEach-Object {
            Write-Host "::warning file=$($_.Name)::$($_.Count) uncovered commands"
          }
          throw "Code coverage $actual% is below the $target% target"
        }

    - name: Upload Coverage
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: coverage
        path: coverage.xml

    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v5
      with:
        files: ./coverage.xml
        flags: powershell
      env:
        CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}

  security-scan:
    needs: validate
    runs-on: windows-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Install Dependencies
      shell: pwsh
      run: |
        # Install-PSResource is in-box on PowerShell 7.4+; Windows PowerShell 5.1 needs PowerShellGet.
        if (Get-Command Install-PSResource -ErrorAction SilentlyContinue) {
            Install-PSResource Pester -Version "[$env:PESTER_VERSION,)" -Scope CurrentUser -TrustRepository
            Install-PSResource PSScriptAnalyzer -Scope CurrentUser -TrustRepository
        }
        else {
            Set-PSRepository PSGallery -InstallationPolicy Trusted
            Install-Module Pester -MinimumVersion $env:PESTER_VERSION -Force -Scope CurrentUser
            Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
        }

    - name: Run Security Tests
      shell: pwsh
      run: |
        Import-Module Pester -MinimumVersion 6.1.0 -Force

        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Security'
        $config.Filter.Tag = 'Security'
        $config.Run.PassThru = $true
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = './SecurityResults.xml'
        $config.Output.CIFormat = 'GithubActions'

        $result = Invoke-Pester -Configuration $config

        # A security suite that discovers zero tests must fail the build.
        # Attack-pattern data built in BeforeAll instead of BeforeDiscovery
        # silently collapses the suite - see security-test-template.md.
        if ($result.TotalCount -eq 0) {
          throw "Security suite discovered no tests - check BeforeDiscovery data"
        }

        if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
          throw "Security tests failed: $($result.FailedCount) critical issue(s) found"
        }

    - name: Run Credential Scan
      shell: pwsh
      run: |
        # Custom credential scanning
        $credentialPatterns = @(
          '(?i)(password|pwd|pass)\s*[:=]\s*["\'''][^"\''\s]{8,}'
          '(?i)(api[_-]?key|apikey)\s*[:=]\s*["\''']?[a-zA-Z0-9]{20,}'
          '(?i)(secret|token)\s*[:=]\s*["\''']?[a-zA-Z0-9]{16,}'
        )

        $issues = @()
        Get-ChildItem -Recurse -Include *.ps1, *.psm1, *.psd1 | ForEach-Object {
          $content = Get-Content $_.FullName -Raw
          foreach ($pattern in $credentialPatterns) {
            if ($content -match $pattern) {
              $issues += "Potential credential leak in $($_.FullName): $($matches[0])"
            }
          }
        }

        if ($issues) {
          $issues | ForEach-Object { Write-Warning $_ }
          throw "Credential leaks detected: $($issues.Count) issues"
        }

  performance-baseline:
    needs: validate
    runs-on: windows-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Install Dependencies
      shell: pwsh
      run: |
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module Pester -MinimumVersion $env:PESTER_VERSION -Force -Scope CurrentUser

    - name: Run Performance Tests
      shell: pwsh
      run: |
        Import-Module Pester -MinimumVersion 6.1.0 -Force

        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Performance'
        $config.Filter.Tag = 'Performance'
        $config.Run.PassThru = $true
        # Never parallel, and never with coverage - both distort the measurement
        $config.Run.Parallel = $false
        $config.CodeCoverage.Enabled = $false
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = './PerformanceResults.xml'

        $result = Invoke-Pester -Configuration $config

        # Performance tests generate warnings, not failures
        if ($result.FailedCount -gt 0) {
          Write-Warning "Performance regression detected: $($result.FailedCount) tests exceeded baseline"
        }

    - name: Store Performance Metrics
      shell: pwsh
      run: |
        # Store performance metrics for trending
        $metrics = @{
          timestamp = Get-Date
          commit = "${{ github.sha }}"
          branch = "${{ github.ref_name }}"
          performance_results = "Performance test results would be parsed here"
        }

        $metrics | ConvertTo-Json | Out-File performance-metrics.json

    - name: Upload Performance Results
      uses: actions/upload-artifact@v4
      with:
        name: performance-results
        path: |
          PerformanceResults.xml
          performance-metrics.json
```

### GitHub Actions Notes

- `actions/setup-powershell` is not an official action. GitHub-hosted runners ship a supported
  PowerShell 7 preinstalled (`shell: pwsh`), and `windows-latest` also has Windows PowerShell 5.1
  (`shell: powershell`). Select the shell rather than installing a version. If your gate requires a
  specific release (for example 7.6 for `Join-Path` multi-segment or `Get-Command -ExcludeModule`),
  assert it rather than assuming the runner image:
  `if ($PSVersionTable.PSVersion -lt [version]'7.6') { throw "Need PowerShell 7.6+, got $($PSVersionTable.PSVersion)" }`
- `::set-output` was disabled by GitHub in 2023. Write to `$GITHUB_OUTPUT` instead:
  `"name=value" | Out-File $env:GITHUB_OUTPUT -Append`.
- `$config.Output.CIFormat = 'GithubActions'` makes Pester emit `::error` and `::warning`
  annotations that surface failures inline on the PR diff. `Auto` detects this, but setting it
  explicitly is clearer.
- Use `fail-fast: false` so one platform's failure does not cancel the others - you want the full
  picture of which platforms broke.

## Azure DevOps Integration

### Azure Pipelines YAML

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    exclude:
    - README.md
    - docs/*

pr:
  branches:
    include:
    - main
  paths:
    exclude:
    - README.md
    - docs/*

schedules:
- cron: "0 2 * * *"
  displayName: Daily Build
  branches:
    include:
    - main

variables:
  POWERSHELL_TELEMETRY_OPTOUT: 1

stages:
- stage: Test
  displayName: 'Testing Stage'
  jobs:
  - job: TestWindows
    displayName: 'Test on Windows'
    pool:
      vmImage: 'windows-latest'
    strategy:
      matrix:
        PS5:
          powershellVersion: '5.1'
        PS7:
          powershellVersion: '7.x'
    steps:
    - task: PowerShell@2
      displayName: 'Install Dependencies'
      inputs:
        targetType: 'inline'
        script: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module Pester -MinimumVersion 6.1.0 -Force -Scope CurrentUser
          Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
        pwsh: $(powershellVersion -eq '7.x')

    - task: PowerShell@2
      displayName: 'Run PSScriptAnalyzer'
      inputs:
        targetType: 'inline'
        script: |
          $results = Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
          if ($results) {
            $results | Format-Table -AutoSize
            Write-Host "##vso[task.logissue type=error]PSScriptAnalyzer found $($results.Count) issues"
            exit 1
          }
        pwsh: $(powershellVersion -eq '7.x')

    - task: PowerShell@2
      displayName: 'Run Tests'
      inputs:
        targetType: 'inline'
        script: |
          Import-Module Pester -MinimumVersion 6.1.0 -Force

          $config = New-PesterConfiguration
          $config.Run.Path = './Tests'
          $config.Run.PassThru = $true
          $config.CodeCoverage.Enabled = $true
          $config.CodeCoverage.Path = './Public/*.ps1', './Private/*.ps1'
          $config.CodeCoverage.OutputFormat = 'JaCoCo'
          $config.CodeCoverage.OutputPath = '$(Agent.TempDirectory)/coverage.xml'
          $config.CodeCoverage.CoveragePercentTarget = 80
          $config.TestResult.Enabled = $true
          $config.TestResult.OutputFormat = 'NUnitXml'
          $config.TestResult.OutputPath = '$(Agent.TempDirectory)/TestResults.xml'
          $config.Output.CIFormat = 'AzureDevops'

          $result = Invoke-Pester -Configuration $config

          Write-Host "##vso[task.setvariable variable=TotalTests]$($result.TotalCount)"
          Write-Host "##vso[task.setvariable variable=PassedTests]$($result.PassedCount)"
          Write-Host "##vso[task.setvariable variable=FailedTests]$($result.FailedCount)"

          # Pester 5/6 property is CoveragePercent. CoveredPercent is the
          # Pester 4 name and returns $null silently.
          if ($result.CodeCoverage) {
            Write-Host "##vso[task.setvariable variable=CodeCoverage]$($result.CodeCoverage.CoveragePercent)"
          }

          # A file that fails discovery contributes 0 to FailedCount - check both
          if ($result.FailedContainersCount -gt 0) {
            $result.FailedContainers | ForEach-Object {
              Write-Host "##vso[task.logissue type=error]Discovery failed: $($_.Item)"
            }
            exit 1
          }

          if ($result.FailedCount -gt 0) {
            Write-Host "##vso[task.logissue type=error]$($result.FailedCount) tests failed"
            exit 1
          }
        pwsh: $(powershellVersion -eq '7.x')

    - task: PublishTestResults@2
      displayName: 'Publish Test Results'
      condition: always()
      inputs:
        testResultsFormat: 'NUnit'
        testResultsFiles: '$(Agent.TempDirectory)/TestResults.xml'
        testRunTitle: 'PowerShell Tests - $(Agent.OS) - PS$(powershellVersion)'

    # PublishCodeCoverageResults@1 is deprecated; @2 takes summaryFileLocation
    # directly and infers the format.
    - task: PublishCodeCoverageResults@2
      displayName: 'Publish Code Coverage'
      condition: always()
      inputs:
        summaryFileLocation: '$(Agent.TempDirectory)/coverage.xml'

  - job: TestLinux
    displayName: 'Test on Linux'
    pool:
      vmImage: 'ubuntu-latest'
    steps:
    - task: PowerShell@2
      displayName: 'Install Dependencies'
      inputs:
        targetType: 'inline'
        script: |
          Set-PSRepository PSGallery -InstallationPolicy Trusted
          Install-Module Pester -MinimumVersion 6.1.0 -Force -Scope CurrentUser
        pwsh: true

    - task: PowerShell@2
      displayName: 'Run Cross-Platform Tests'
      inputs:
        targetType: 'inline'
        script: |
          $config = New-PesterConfiguration
          $config.Run.Path = './Tests/Unit'
          $config.Filter.Tag = 'CrossPlatform'
          $config.Run.PassThru = $true
          $config.TestResult.Enabled = $true
          $config.TestResult.OutputPath = '$(Agent.TempDirectory)/LinuxTestResults.xml'

          $result = Invoke-Pester -Configuration $config

          if ($result.FailedCount -gt 0) {
            Write-Host "##vso[task.logissue type=error]Cross-platform tests failed: $($result.FailedCount) failures"
            exit 1
          }
        pwsh: true

- stage: Security
  displayName: 'Security Scanning'
  dependsOn: Test
  condition: succeeded()
  jobs:
  - job: SecurityScan
    displayName: 'Security Analysis'
    pool:
      vmImage: 'windows-latest'
    steps:
    - task: PowerShell@2
      displayName: 'Security Tests'
      inputs:
        targetType: 'inline'
        script: |
          Install-Module Pester -Force -Scope CurrentUser

          $config = New-PesterConfiguration
          $config.Run.Path = './Tests/Security'
          $config.Filter.Tag = 'Security'
          $config.Run.PassThru = $true

          $result = Invoke-Pester -Configuration $config

          if ($result.FailedCount -gt 0) {
            Write-Host "##vso[task.logissue type=error]Security tests failed: $($result.FailedCount) critical issues"
            exit 1
          }

- stage: Deploy
  displayName: 'Deployment'
  dependsOn:
  - Test
  - Security
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployProduction
    displayName: 'Deploy to PowerShell Gallery'
    environment: 'Production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: PowerShell@2
            displayName: 'Publish to PowerShell Gallery'
            inputs:
              targetType: 'inline'
              script: |
                # Publish logic here
                Write-Host "Publishing to PowerShell Gallery..."
```

## Jenkins Integration

### Jenkinsfile

```groovy
pipeline {
    agent none

    environment {
        POWERSHELL_TELEMETRY_OPTOUT = '1'
    }

    stages {
        stage('Test') {
            parallel {
                stage('Windows PowerShell 5.1') {
                    agent { label 'windows' }
                    steps {
                        powershell '''
                            Set-PSRepository PSGallery -InstallationPolicy Trusted
                            Install-Module Pester -MinimumVersion 6.1.0 -Force -Scope CurrentUser

                            $config = New-PesterConfiguration
                            $config.Run.Path = './Tests'
                            $config.Run.PassThru = $true
                            $config.TestResult.Enabled = $true
                            $config.TestResult.OutputPath = './TestResults.xml'

                            $result = Invoke-Pester -Configuration $config

                            if ($result.FailedCount -gt 0) {
                                exit 1
                            }
                        '''
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'TestResults.xml'
                        }
                    }
                }

                stage('PowerShell 7.x') {
                    agent { label 'pwsh' }
                    steps {
                        pwsh '''
                            Set-PSRepository PSGallery -InstallationPolicy Trusted
                            Install-Module Pester -MinimumVersion 6.1.0 -Force -Scope CurrentUser

                            ./Invoke-Tests.ps1 -TestType All -Environment CI -CodeCoverage
                        '''
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: 'Tests/Results/*.xml'
                            publishCoverage adapters: [jacocoAdapter('Tests/Results/Coverage*.xml')]
                        }
                    }
                }
            }
        }

        stage('Security Scan') {
            agent { label 'windows' }
            steps {
                powershell '''
                    ./Invoke-Tests.ps1 -TestType Security -Environment CI
                '''
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
                allOf {
                    environment name: 'BUILD_STATUS', value: 'SUCCESS'
                }
            }
            agent { label 'windows' }
            steps {
                powershell '''
                    # Deployment logic
                    Write-Host "Deploying to PowerShell Gallery..."
                '''
            }
        }
    }

    post {
        always {
            emailext (
                to: '${DEFAULT_RECIPIENTS}',
                subject: '${PROJECT_NAME} - Build ${BUILD_NUMBER} - ${BUILD_STATUS}',
                body: '''${PROJECT_NAME} - Build ${BUILD_NUMBER} - ${BUILD_STATUS}

                Test Results:
                Total Tests: ${TEST_COUNTS,var="total"}
                Failed Tests: ${TEST_COUNTS,var="fail"}
                Passed Tests: ${TEST_COUNTS,var="pass"}
                Skipped Tests: ${TEST_COUNTS,var="skip"}

                Build URL: ${BUILD_URL}
                '''
            )
        }
    }
}
```

## GitLab CI Integration

### .gitlab-ci.yml

```yaml
stages:
  - test
  - security
  - deploy

variables:
  POWERSHELL_TELEMETRY_OPTOUT: "1"

.powershell_template: &powershell_template
  before_script:
    - Set-PSRepository PSGallery -InstallationPolicy Trusted
    - Install-Module Pester -MinimumVersion 6.1.0 -Force -Scope CurrentUser

# GitLab needs JUnit for test results and Cobertura for coverage. Pester 6
# supports both natively - set TestResult.OutputFormat = 'JUnitXml' and
# CodeCoverage.OutputFormat = 'Cobertura' in PesterConfiguration.CI.psd1.
#
# Container images: the `mcr.microsoft.com/powershell` images are DEPRECATED. PowerShell now
# ships inside the .NET SDK images - `mcr.microsoft.com/dotnet/sdk:10.0` carries PowerShell 7.6
# (.NET 10 LTS). Microsoft publishes these for development and testing only; build and maintain
# your own image for production pipelines.
test:windows:
  stage: test
  image: mcr.microsoft.com/dotnet/sdk:10.0-windowsservercore-ltsc2022
  <<: *powershell_template
  script:
    - ./Invoke-Tests.ps1 -TestType Unit -Environment CI -CodeCoverage
  artifacts:
    reports:
      junit: Tests/Results/TestResults*.xml
      coverage_report:
        coverage_format: cobertura
        path: Tests/Results/Coverage*.xml
    paths:
      - Tests/Results/
    expire_in: 1 week
  coverage: '/Code Coverage: (\d+\.?\d*)%/'

test:linux:
  stage: test
  image: mcr.microsoft.com/dotnet/sdk:10.0
  <<: *powershell_template
  script:
    # Parallel is safe here - no coverage on this job
    - pwsh -Command "./Invoke-Tests.ps1 -TestType Unit -Tag CrossPlatform -Environment CI -Parallel"
  artifacts:
    reports:
      junit: Tests/Results/TestResults*.xml

security:
  stage: security
  image: mcr.microsoft.com/dotnet/sdk:10.0-windowsservercore-ltsc2022
  <<: *powershell_template
  script:
    - ./Invoke-Tests.ps1 -TestType Security -Environment CI
  allow_failure: false

deploy:
  stage: deploy
  image: mcr.microsoft.com/dotnet/sdk:10.0-windowsservercore-ltsc2022
  script:
    - Write-Host "Deploying to PowerShell Gallery..."
  only:
    - main
  when: manual
```

## CI/CD Best Practices

### Environment Variables

```powershell
# Common environment variables for CI/CD
$env:POWERSHELL_TELEMETRY_OPTOUT = '1'
$env:PESTER_CI_MODE = 'true'
$env:CODE_COVERAGE_ENABLED = 'true'
$env:TEST_RESULTS_PATH = './Tests/Results'
```

### Parallel Test Execution

Pester 6 has a built-in parallel runner. `Run.Container` is for _parametrizing_ files, not for
parallelism - the old snippet using multiple containers ran sequentially.

```powershell
# Actual parallel execution: one file per runspace, PowerShell 7+ only
$config = New-PesterConfiguration
$config.Run.Path = './Tests/Unit'
$config.Run.Parallel = $true
$config.Run.ParallelThrottleLimit = 4   # 0 (default) uses all processors
```

Parametrized containers still work, and they parallelize too:

```powershell
$config.Run.Container = @(
    New-PesterContainer -Path './Tests/Unit' -Data @{ Environment = 'CI' }
)
$config.Run.Parallel = $true   # each file's -Data reaches its worker intact
```

**Coverage under parallel changed in 6.1.** Pester 6.0 collected no coverage in a parallel run; 6.1
merges it across workers, but forces slower breakpoint-based collection to do it. Splitting into two
jobs is still the better default - a parallel job without coverage for feedback, and a sequential
job with the profiler for the gate - but measure before assuming either is faster.

Each worker starts from a **clean runspace**, so every test file must be self-contained. Provide
shared bootstrap through a `Pester.BeforeContainer.ps1` at the repository root, which Pester
dot-sources before every container:

```powershell
# Pester.BeforeContainer.ps1, at the repository root
. "$PSScriptRoot/Tests/TestHelpers/Bootstrap.ps1"
```

The `Run.BeforeContainer` option was removed in 6.1 - a CI job that still sets it now throws. In CI
also set `Run.RepoRoot` explicitly, because the default is resolved from the .NET process working
directory and a job that runs Pester from a subdirectory will not find the bootstrap file:

```powershell
$config.Run.RepoRoot = $env:GITHUB_WORKSPACE   # or the equivalent for your CI system
```

Verify isolation before enabling parallel in CI - if a file only passes as part of a full run, it is
not self-contained:

```powershell
Get-ChildItem ./Tests/Unit -Recurse -Filter *.Tests.ps1 | ForEach-Object {
    $r = Invoke-Pester -Path $_.FullName -PassThru -Output None
    if ($r.FailedCount -gt 0 -or $r.FailedContainersCount -gt 0) {
        Write-Warning "Not self-contained: $($_.FullName)"
    }
}
```

### Artifact Management

```powershell
# Standardized artifact collection
$artifacts = @{
    TestResults = './Tests/Results/TestResults*.xml'
    CodeCoverage = './Tests/Results/Coverage*.xml'
    PerformanceMetrics = './Tests/Results/Performance*.json'
    SecurityReports = './Tests/Results/Security*.xml'
}
```

### Report Format by Platform

| Platform | Test results | Coverage |
| --- | --- | --- |
| GitHub Actions (`dorny/test-reporter`) | `NUnitXml` | `JaCoCo` |
| Azure DevOps (`PublishTestResults@2`) | `NUnitXml` | `JaCoCo` |
| GitLab CI | `JUnitXml` | `Cobertura` |
| Jenkins (JUnit plugin) | `JUnitXml` | `JaCoCo` |
| Codecov | any | `JaCoCo` or `Cobertura` |

`Cobertura` and `NUnit3` are new in Pester 6. `CoverageGutters` was **removed** - all coverage output
is now repo-root-relative, so plain `JaCoCo` works with the Coverage Gutters extension.

Coverage paths are relative to `CodeCoverage.ReportRoot`, which defaults to `Run.RepoRoot` (found
from the `.git` directory). If your CI checks out to a subdirectory and paths do not line up in the
report, set `ReportRoot` explicitly.

`TestResult` writes one format per run. For two, convert the result object afterwards:

```powershell
$config.Run.PassThru = $true
$result = Invoke-Pester -Configuration $config
Export-NUnitReport -Result $result -Path './Tests/Results/NUnit.xml'
Export-JUnitReport -Result $result -Path './Tests/Results/JUnit.xml'
```

### CI Gate Checklist

A Pester 6 gate must check more than `FailedCount`:

```powershell
$result = Invoke-Pester -Configuration $config

# 1. Test failures
if ($result.FailedCount -gt 0) { throw "$($result.FailedCount) test(s) failed" }

# 2. Discovery/container failures - these contribute 0 to FailedCount.
#    Without this check, whole files can silently never run.
if ($result.FailedContainersCount -gt 0) { throw "$($result.FailedContainersCount) file(s) failed discovery" }

# 3. Zero tests discovered - a suite that tests nothing must not report success
if ($result.TotalCount -eq 0) { throw 'No tests were discovered' }

# 4. Coverage target - CoveragePercentTarget does not fail the run on its own
if ($result.CodeCoverage) {
    $actual = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
    $target = $result.CodeCoverage.CoveragePercentTarget
    if ($actual -lt $target) { throw "Coverage $actual% below $target% target" }
}
```

Items 2 and 3 are the ones a Pester 5 pipeline will not have, and they are exactly how a v6 upgrade
turns green while running fewer tests than before.
