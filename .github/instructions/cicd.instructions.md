---
mode: 'agent'
applyTo: "**/.github/workflows/*.yml,**/.github/workflows/*.yaml,**/azure-pipelines.yml,**/build.ps1,**/deploy.ps1"
tools: ['codebase', 'githubRepo']
description: 'Sets up comprehensive CI/CD pipelines for PowerShell projects with automated testing and deployment'
---

# PowerShell CI/CD Pipeline Configuration

Create robust CI/CD pipelines for PowerShell projects with automated testing, quality gates, security scanning, and
deployment automation. Support multiple platforms while maintaining enterprise standards.

## Pipeline Requirements Assessment

First, determine the pipeline requirements:

### Project Information Needed

- **Platform Preference**: Azure DevOps, GitHub Actions, GitLab CI, or Jenkins
- **PowerShell Versions**: PowerShell 7.6 (LTS, default), or 5.1 + 7.6 when Windows PowerShell support is required.
  Retire 7.4/7.5-only matrices before 10-Nov-2026, when both reach end of support
- **Target Environments**: Development, Testing, Staging, Production
- **Deployment Targets**: PowerShell Gallery, internal repositories, or direct deployment
- **Security Requirements**: Code signing, credential management, compliance scanning

### Quality Gates to Implement

- **Code Quality**: PSScriptAnalyzer validation with zero errors
- **Testing**: Minimum 80% code coverage with Pester tests
- **Security**: Credential scanning and vulnerability assessment
- **Performance**: Execution time and memory usage baselines
- **Documentation**: README and troubleshooting documentation validation
- **Help Docs**: PlatyPS Markdown structure valid, no placeholders, no drift against exported commands

## Pipeline Configuration

### Azure DevOps Pipeline

Generate complete Azure DevOps YAML pipeline with:

```yaml
# Key components to include:
stages:
  - Build and Validate
  - Security Scanning
  - Package Creation
  - Environment Deployments
  - PowerShell Gallery Publishing
```

**Required Pipeline Features:**

- Multi-stage pipeline with approval gates
- Parallel job execution for different PowerShell versions
- Artifact management and retention
- Environment-specific variable groups
- Integration with Azure Key Vault for secrets
- Automated rollback on deployment failure

### GitHub Actions Workflow

Create comprehensive GitHub Actions workflow including:

```yaml
# Essential workflow components:
jobs:
  - build-and-test (matrix strategy for PS versions)
  - security-scan
  - package-artifact
  - deploy-environments
  - publish-gallery
```

**Required Workflow Features:**

- Matrix builds for PowerShell version compatibility
- Conditional execution based on branch and tags
- Secret management with GitHub Secrets
- Artifact upload and download between jobs
- Environment protection rules
- Integration with third-party security tools

### Quality Gate Implementation

#### Code Quality Validation

```powershell
# PSScriptAnalyzer execution with enterprise rules
$analysisResults = Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSGallery
if ($analysisResults) {
    Write-Error "PSScriptAnalyzer issues found: $($analysisResults.Count)"
    exit 1
}
```

`-Settings` takes any of the presets PSScriptAnalyzer ships, so the formatting rules in
[style-enforcement.instructions.md](./style-enforcement.instructions.md) do not need a hand-written
settings file. `CodeFormattingOTBS` already configures them:

```powershell
# One True Brace Style, 4-space indentation, operator and separator spacing,
# assignment alignment, and cmdlet casing - all built in
Invoke-ScriptAnalyzer -Path . -Recurse -Settings CodeFormattingOTBS
```

Run both when a team wants correctness and formatting checked together. The one documented rule no
preset covers is the 115-character line limit; add `PSAvoidLongLines` explicitly if it matters to
the team.

Which presets to adopt is the consuming team's decision - these standards describe the practices,
not the audit configuration.

#### Testing and Coverage

```powershell
# Pester 6 test execution with coverage
Import-Module Pester -MinimumVersion 6.1.0 -Force

$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = './Tests'
$pesterConfig.Run.PassThru = $true
$pesterConfig.CodeCoverage.Enabled = $true
$pesterConfig.CodeCoverage.Path = './Public/*.ps1', './Private/*.ps1'
# CoveragePercentTarget, not Threshold - CodeCoverage.Threshold does not exist
$pesterConfig.CodeCoverage.CoveragePercentTarget = 80

$result = Invoke-Pester -Configuration $pesterConfig

# A file that fails discovery contributes 0 to FailedCount - check both
if ($result.FailedCount -gt 0 -or $result.FailedContainersCount -gt 0) {
    Write-Error "Tests failed: $($result.FailedCount) test(s), $($result.FailedContainersCount) container(s)"
    exit 1
}

# CoveragePercentTarget is the reported target; enforce the gate yourself
$coverage = [math]::Round($result.CodeCoverage.CoveragePercent, 2)
if ($coverage -lt 80) {
    Write-Error "Code coverage $coverage% is below the 80% target"
    exit 1
}
```

See [Pester instructions](./pester.instructions.md) for the full testing standards.

#### Security Scanning

```powershell
# Credential and security scanning
$securityScan = Test-ScriptSecurity -Path . -RecursiveSearch
if ($securityScan.HighRiskFindings) {
    Write-Error "Security vulnerabilities detected"
    exit 1
}
```

## Deployment Strategies

### Environment Promotion

Design deployment pipeline with:

- **Development**: Automatic deployment on feature branch commits
- **Testing**: Automatic deployment on main branch commits
- **Staging**: Manual approval required, mirrors production
- **Production**: Requires multiple approvals and change management

### Blue-Green Deployment

Implement zero-downtime deployment strategy:

- Deploy to inactive environment slot
- Run smoke tests and health checks
- Switch traffic to new deployment
- Keep previous version for rapid rollback

### PowerShell Gallery Publishing

Configure automated publishing with:

- Semantic versioning based on commit messages
- Pre-release versions for development branches
- Release notes generation from changelog
- API key management through secure secret storage

## Security Integration

### Code Signing

Set up automated code signing:

- Certificate management in secure storage
- Timestamp server configuration
- Validation of signature integrity
- Support for different certificate types per environment

### Credential Management

Implement secure credential handling:

- Integration with Azure Key Vault or GitHub Secrets
- No hardcoded credentials in pipeline files
- Secure injection of credentials at runtime
- Audit logging of credential access

### Vulnerability Scanning

Configure security scanning tools:

- Dependency vulnerability scanning
- Static code analysis for security issues
- Container scanning (if using containerized builds)
- Integration with security monitoring systems

## Performance Monitoring

### Build Performance

Monitor and optimize:

- Build execution time tracking
- Test execution duration monitoring
- Artifact size optimization
- Resource usage monitoring

### Deployment Metrics

Track deployment success:

- Deployment frequency and duration
- Failure rates and root causes
- Mean time to recovery (MTTR)
- Change failure rate

## Troubleshooting Integration

### Pipeline Diagnostics

Implement comprehensive logging:

- Correlation IDs throughout pipeline execution
- Structured logging with appropriate detail levels
- Integration with centralized logging systems
- Error categorization and automated triage

### Documentation Generation

Automate troubleshooting documentation:

- Generate pipeline status reports
- Create deployment summaries
- Update troubleshooting guides in `./Troubleshooting/` folder
- Maintain runbook documentation

### Command Help Gate

Command help is built and validated in the pipeline, not by hand. Full mechanics in
[platyps.instructions.md](./platyps.instructions.md).

```powershell
# Pull request: validate the committed Markdown and fail on drift
#Requires -Modules @{ ModuleName = 'Microsoft.PowerShell.PlatyPS'; ModuleVersion = '1.0.3' }

Import-Module ./ModuleName.psd1 -Force

# 1. Structure
Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Test-MarkdownCommandHelp -Path {$_.FilePath} -DetailView

# 2. No unfilled templates
$unfilled = Select-String -Path ./docs/ModuleName/*.md -Pattern '\{\{\s*Fill in' -List
if ($unfilled) {
    Write-Error "Unfilled help placeholders in: $(($unfilled.Path | Split-Path -Leaf) -join ', ')" -ErrorAction Stop
}

# 3. Drift - every exported command documented, nothing documented that is gone
$documented = (Get-ChildItem ./docs/ModuleName/*.md).BaseName | Where-Object { $_ -ne 'ModuleName' }
$exported = (Get-Module ModuleName).ExportedFunctions.Keys
$drift = @($exported | Where-Object { $_ -notin $documented }) +
         @($documented | Where-Object { $_ -notin $exported })
if ($drift) {
    Write-Error "Help is out of sync with exported commands: $($drift -join ', ')" -ErrorAction Stop
}
```

The `package-artifact` job builds MAML into the module before packaging, so the published module
always ships current help:

```powershell
Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Import-MarkdownCommandHelp -Path {$_.FilePath} |
    Export-MamlCommandHelp -OutputFolder ./maml -Force

$cultureDir = Join-Path $ModuleOutputPath 'en-US'
New-Item -Path $cultureDir -ItemType Directory -Force | Out-Null
Copy-Item ./maml/ModuleName/ModuleName-Help.xml -Destination $cultureDir -Force
```

Install PlatyPS in the runner alongside the other build dependencies:

```yaml
- name: Install build modules
  shell: pwsh
  run: |
    Install-PSResource -Name Pester, PSScriptAnalyzer, Microsoft.PowerShell.PlatyPS -TrustRepository
```

## Configuration Templates

Provide ready-to-use pipeline configurations for:

### Basic PowerShell Module Pipeline

- Simple module with unit tests
- PowerShell Gallery publishing
- Multi-version compatibility testing

### Enterprise Application Pipeline

- Complex multi-module solution
- Integration testing with external dependencies
- Security compliance validation
- Multi-environment deployment

### Script Library Pipeline

- Collection of standalone PowerShell scripts
- Individual script validation and testing
- Centralized distribution and versioning

## Best Practices Implementation

### Pipeline as Code

- Version control all pipeline definitions
- Use templates and reusable components
- Implement proper change management
- Maintain pipeline documentation

### Monitoring and Alerting

- Pipeline execution monitoring
- Failure notification systems
- Performance trend analysis
- SLA tracking and reporting

### Compliance and Governance

- Audit trail maintenance
- Change approval workflows
- Security scanning integration
- Regulatory compliance validation

## Output Deliverables

Generate complete pipeline configuration including:

1. **Pipeline Definition Files**: YAML/JSON configurations ready for deployment
2. **Environment Configuration**: Variable templates and secret management setup
3. **Quality Gate Scripts**: PowerShell scripts for validation and testing
4. **Deployment Scripts**: Automated deployment and rollback procedures
5. **Documentation**: Pipeline setup guide and troubleshooting procedures
6. **Monitoring Configuration**: Dashboards and alerting rules

Ensure all generated configurations follow enterprise PowerShell development standards and integrate with the
established troubleshooting documentation structure in `./Troubleshooting/` folders.
