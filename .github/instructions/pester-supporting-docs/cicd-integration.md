# CI/CD Integration Guide

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

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [windows-latest, ubuntu-latest, macos-latest]
        powershell-version: ['5.1', '7.2', '7.3', '7.4']
        exclude:
          - os: ubuntu-latest
            powershell-version: '5.1'
          - os: macos-latest
            powershell-version: '5.1'

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Setup PowerShell
      uses: actions/setup-powershell@v1
      with:
        powershell-version: ${{ matrix.powershell-version }}

    - name: Cache PowerShell Modules
      uses: actions/cache@v3
      with:
        path: |
          ~/.local/share/powershell/Modules
          ~/Documents/PowerShell/Modules
        key: ${{ runner.os }}-powershell-${{ hashFiles('**/*.psd1') }}
        restore-keys: |
          ${{ runner.os }}-powershell-

    - name: Install Dependencies
      shell: pwsh
      run: |
        Set-PSRepository PSGallery -InstallationPolicy Trusted
        Install-Module Pester -MinimumVersion 5.3.0 -Force -Scope CurrentUser
        Install-Module PSScriptAnalyzer -Force -Scope CurrentUser

    - name: Run PSScriptAnalyzer
      shell: pwsh
      run: |
        $analysisResults = Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
        if ($analysisResults) {
          $analysisResults | Format-Table -AutoSize
          throw "PSScriptAnalyzer found $($analysisResults.Count) issues"
        }

    - name: Run Unit Tests
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Unit'
        $config.Run.PassThru = $true
        $config.CodeCoverage.Enabled = $true
        $config.CodeCoverage.Path = './Public/*.ps1', './Private/*.ps1'
        $config.CodeCoverage.OutputFormat = 'JaCoCo'
        $config.CodeCoverage.OutputPath = './coverage.xml'
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = './TestResults.xml'
        $config.Output.Verbosity = 'Detailed'

        $result = Invoke-Pester -Configuration $config

        if ($result.FailedCount -gt 0) {
          throw "Unit tests failed: $($result.FailedCount) failures"
        }

    - name: Run Integration Tests
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Integration'
        $config.Run.PassThru = $true
        $config.Filter.Tag = 'Integration'
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputFormat = 'NUnitXml'
        $config.TestResult.OutputPath = './IntegrationResults.xml'

        $result = Invoke-Pester -Configuration $config

        if ($result.FailedCount -gt 0) {
          Write-Warning "Integration tests failed: $($result.FailedCount) failures"
          # Don't fail the build for integration test failures
        }

    - name: Upload Test Results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results-${{ matrix.os }}-ps${{ matrix.powershell-version }}
        path: |
          TestResults.xml
          IntegrationResults.xml
          coverage.xml

    - name: Publish Test Results
      uses: dorny/test-reporter@v1
      if: always()
      with:
        name: Test Results (${{ matrix.os }} - PS${{ matrix.powershell-version }})
        path: TestResults.xml
        reporter: dotnet-trx

    - name: Upload Coverage to Codecov
      uses: codecov/codecov-action@v3
      if: matrix.os == 'windows-latest' && matrix.powershell-version == '7.4'
      with:
        file: ./coverage.xml
        flags: powershell
        name: codecov-umbrella

  security-scan:
    runs-on: windows-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Setup PowerShell
      uses: actions/setup-powershell@v1

    - name: Install Dependencies
      shell: pwsh
      run: |
        Install-Module Pester -Force -Scope CurrentUser
        Install-Module PSScriptAnalyzer -Force -Scope CurrentUser

    - name: Run Security Tests
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Security'
        $config.Filter.Tag = 'Security'
        $config.Run.PassThru = $true
        $config.TestResult.Enabled = $true
        $config.TestResult.OutputPath = './SecurityResults.xml'

        $result = Invoke-Pester -Configuration $config

        if ($result.FailedCount -gt 0) {
          throw "Security tests failed: $($result.FailedCount) critical issues found"
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
    runs-on: windows-latest
    steps:
    - name: Checkout Repository
      uses: actions/checkout@v4

    - name: Setup PowerShell
      uses: actions/setup-powershell@v1

    - name: Install Dependencies
      shell: pwsh
      run: |
        Install-Module Pester -Force -Scope CurrentUser

    - name: Run Performance Tests
      shell: pwsh
      run: |
        $config = New-PesterConfiguration
        $config.Run.Path = './Tests/Performance'
        $config.Filter.Tag = 'Performance'
        $config.Run.PassThru = $true
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
      uses: actions/upload-artifact@v3
      with:
        name: performance-results
        path: |
          PerformanceResults.xml
          performance-metrics.json
```

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
          Install-Module Pester -MinimumVersion 5.3.0 -Force -Scope CurrentUser
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
          $config = New-PesterConfiguration
          $config.Run.Path = './Tests'
          $config.Run.PassThru = $true
          $config.CodeCoverage.Enabled = $true
          $config.CodeCoverage.Path = './Public/*.ps1', './Private/*.ps1'
          $config.CodeCoverage.OutputFormat = 'JaCoCo'
          $config.CodeCoverage.OutputPath = '$(Agent.TempDirectory)/coverage.xml'
          $config.TestResult.Enabled = $true
          $config.TestResult.OutputFormat = 'NUnitXml'
          $config.TestResult.OutputPath = '$(Agent.TempDirectory)/TestResults.xml'

          $result = Invoke-Pester -Configuration $config

          Write-Host "##vso[task.setvariable variable=TotalTests]$($result.TotalCount)"
          Write-Host "##vso[task.setvariable variable=PassedTests]$($result.PassedCount)"
          Write-Host "##vso[task.setvariable variable=FailedTests]$($result.FailedCount)"

          if ($result.CodeCoverage) {
            Write-Host "##vso[task.setvariable variable=CodeCoverage]$($result.CodeCoverage.CoveredPercent)"
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

    - task: PublishCodeCoverageResults@1
      displayName: 'Publish Code Coverage'
      condition: always()
      inputs:
        codeCoverageTool: 'JaCoCo'
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
          Install-Module Pester -MinimumVersion 5.3.0 -Force -Scope CurrentUser
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
                            Install-Module Pester -MinimumVersion 5.3.0 -Force -Scope CurrentUser

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
                            Install-Module Pester -MinimumVersion 5.3.0 -Force -Scope CurrentUser

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
    - Install-Module Pester -MinimumVersion 5.3.0 -Force -Scope CurrentUser

test:windows:
  stage: test
  image: mcr.microsoft.com/powershell:lts-windowsservercore-ltsc2019
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
  image: mcr.microsoft.com/powershell:lts-ubuntu-20.04
  <<: *powershell_template
  script:
    - pwsh -Command "./Invoke-Tests.ps1 -TestType Unit -Tag CrossPlatform -Environment CI"
  artifacts:
    reports:
      junit: Tests/Results/TestResults*.xml

security:
  stage: security
  image: mcr.microsoft.com/powershell:lts-windowsservercore-ltsc2019
  <<: *powershell_template
  script:
    - ./Invoke-Tests.ps1 -TestType Security -Environment CI
  allow_failure: false

deploy:
  stage: deploy
  image: mcr.microsoft.com/powershell:lts-windowsservercore-ltsc2019
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
```powershell
# Configure for parallel execution in CI
$config.Run.Container = [Pester.ContainerInfo[]]@(
    New-PesterContainer -Path './Tests/Unit' -Data @{Environment='CI'}
    New-PesterContainer -Path './Tests/Integration' -Data @{Environment='CI'}
)
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
