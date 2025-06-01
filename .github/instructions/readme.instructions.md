---
mode: 'edit'
applyTo: "**/README.md,**/readme.md,**/Readme.md"
description: 'Creates comprehensive, enterprise-grade README documentation for PowerShell projects'
---

# PowerShell README Documentation Generator

Create comprehensive, enterprise-grade README documentation that serves as both technical reference and business communication tool. Generate documentation that supports automatic integration, provides clear value proposition, and maintains consistency with organizational standards.

## README Generation Requirements

### Content Assessment
Gather information needed for complete README generation:

#### Project Information
- **Project Name**: Clear, descriptive name following PowerShell conventions
- **Primary Purpose**: Business value and technical function
- **Target Audience**: System administrators, developers, end users, or automation systems
- **Key Features**: Core capabilities and unique value propositions
- **Dependencies**: Required modules, system requirements, and external services
- **Current Status**: Development phase, version, and maturity level

#### Technical Specifications
- **PowerShell Versions**: Compatibility with Windows PowerShell 5.1 and PowerShell 7.x
- **Platform Support**: Windows, Linux, macOS, or cross-platform
- **Installation Methods**: PowerShell Gallery, manual installation, or enterprise deployment
- **Configuration Requirements**: Environment setup, credentials, and permissions
- **Integration Points**: External systems, APIs, databases, or services

## Comprehensive README Structure

### Generate Complete README with Required Sections

#### Header Section with Badges
```markdown
# Project Title

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](./Actions)
[![PowerShell Gallery](https://img.shields.io/badge/PowerShell%20Gallery-v1.0.0-blue)](https://www.powershellgallery.com/)
[![License](https://img.shields.io/badge/license-MIT-green)](./LICENSE)
[![Coverage](https://img.shields.io/badge/coverage-85%25-brightgreen)](./Tests/Results/)
```

#### 📖 Overview Section
Create compelling overview with business focus:

```markdown
## 📖 Overview

**Business Value:** [Clear ROI statement and organizational benefits]

**Technical Summary:** [High-level description of what the solution does]

### Key Features
- 🚀 **Feature 1**: Business impact and technical capability
- 📊 **Feature 2**: Performance improvements and efficiency gains
- 🔔 **Feature 3**: Automation capabilities and time savings
- 🛡️ **Feature 4**: Security controls and compliance features
- 📱 **Feature 5**: User experience and accessibility improvements

### Target Audience
- **System Administrators**: Daily operations and troubleshooting tasks
- **Infrastructure Managers**: Capacity planning and strategic decisions
- **DevOps Teams**: CI/CD integration and automation workflows
- **Compliance Officers**: Audit trails and regulatory requirements
```

#### 🚀 Quick Start Section
Provide immediate value with copy-paste examples:

```markdown
## 🚀 Quick Start

**TL;DR for experienced users:**

```powershell
# One-line installation and basic usage
Install-Module ModuleName -Scope CurrentUser
Get-ModuleFunction -Parameter "Value" -ExportFormat HTML
```

**Expected Output:**
```
✅ Processing completed successfully
📊 Results: 15 items processed in 2.3 seconds
📄 Report: .\Reports\Output_2024-01-15.html
```

**Next Steps:** See [Configuration](#️-configuration) for enterprise setup and [Advanced Examples](#advanced-scenarios) for automation patterns.
```

#### 📋 Prerequisites Section
Comprehensive requirements documentation:

```markdown
## 📋 Prerequisites

### System Requirements
| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **PowerShell** | 5.1 | 7.4+ | Cross-platform support in 7.x |
| **Operating System** | Windows 10 | Windows Server 2019+ | Linux/macOS supported in PS 7.x |
| **Memory** | 2GB RAM | 8GB+ RAM | Depends on dataset size |
| **Disk Space** | 100MB | 1GB+ | For logs, reports, and temporary files |
| **Network** | 1 Mbps | 10 Mbps+ | For multi-server environments |

### Dependencies
```powershell
# Install required PowerShell modules
Install-Module PSFramework -Scope CurrentUser
Install-Module ImportExcel -Scope CurrentUser
```

| Module | Version | Purpose | Installation |
|--------|---------|---------|--------------|
| **PSFramework** | 1.7.0+ | Structured logging and configuration | `Install-Module PSFramework` |
| **ImportExcel** | 7.8.0+ | Excel report generation | `Install-Module ImportExcel` |

### Permissions & Access
<details>
<summary>🔐 Detailed Permission Requirements</summary>

#### Service Account Setup
1. **Domain Account**: Recommended for enterprise environments
2. **Local Administrator**: Required on target systems
3. **WinRM Access**: Remote PowerShell connectivity

#### Network Requirements
| Protocol | Port | Direction | Purpose |
|----------|------|-----------|---------|
| **WinRM HTTP** | 5985 | Outbound | Remote PowerShell (default) |
| **WinRM HTTPS** | 5986 | Outbound | Secure remote PowerShell |
| **SMTP** | 25/587 | Outbound | Email reporting |

</details>
```

#### 🔧 Installation Section
Multiple installation methods with validation:

```markdown
## 🔧 Installation

### Method 1: PowerShell Gallery (Recommended)
```powershell
# Install latest stable version
Install-Module ModuleName -Scope CurrentUser

# Verify installation
Get-Module ModuleName -ListAvailable
```

### Method 2: Manual Installation
1. **Download Latest Release**
   ```powershell
   $url = "https://github.com/user/repo/releases/latest/download/ModuleName.zip"
   Invoke-WebRequest -Uri $url -OutFile "ModuleName.zip"
   ```

2. **Extract and Verify**
   ```powershell
   Expand-Archive -Path "ModuleName.zip" -DestinationPath "C:\Scripts\ModuleName"

   # Verify digital signature (recommended)
   Get-AuthenticodeSignature -FilePath "C:\Scripts\ModuleName\ModuleName.ps1"
   ```

### Method 3: Enterprise Deployment
```powershell
# Using organizational package manager or deployment system
Deploy-EnterpriseModule -ModuleName "ModuleName" -Version "1.0.0" -TargetComputers $ServerList
```
```

#### ⚙️ Configuration Section
Environment-specific configuration guidance:

```markdown
## ⚙️ Configuration

### Basic Configuration
```powershell
# Copy and customize configuration template
Copy-Item ".\Templates\config-template.json" ".\config.json"

# Edit configuration for your environment
notepad ".\config.json"
```

### Configuration File Structure
```json
{
  "environment": "Production",
  "logging": {
    "level": "Information",
    "path": "./Logs/",
    "retention": "30 days"
  },
  "email": {
    "smtpServer": "smtp.company.com",
    "fromAddress": "monitoring@company.com",
    "recipients": ["it-team@company.com"]
  },
  "thresholds": {
    "cpu": 80,
    "memory": 85,
    "disk": 90
  }
}
```

### Environment Variables
```powershell
# Set environment-specific variables
$env:MODULE_CONFIG_PATH = "C:\Config\production-config.json"
$env:MODULE_LOG_LEVEL = "Information"
```
```

#### 💡 Usage Section
Progressive examples from basic to enterprise:

```markdown
## 💡 Usage

### Basic Operations

#### Example 1: Simple Execution
```powershell
# Basic usage with minimal parameters
Get-ModuleFunction -ComputerName "SERVER01"
```

**Expected Output:**
```
🔍 Analyzing SERVER01...
✅ Status: Healthy (Score: 92%)
📊 CPU: 45% | Memory: 62% | Disk: 78%
⏱️  Completed in 28 seconds
```

#### Example 2: Multiple Targets with Custom Settings
```powershell
# Advanced scenario with multiple servers and custom thresholds
$servers = "WEB01", "WEB02", "WEB03"
Get-ModuleFunction -ComputerName $servers -Threshold 75 -ExportFormat HTML -Verbose
```

**Business Use Case:** Weekly infrastructure review preparation with visual dashboard

### Advanced Scenarios

#### Enterprise Active Directory Integration
```powershell
# Automated discovery and monitoring of domain servers
Get-ADComputer -Filter "OperatingSystem -like '*Server*'" -SearchBase "OU=Servers,DC=contoso,DC=com" |
    Select-Object -ExpandProperty Name |
    Get-ModuleFunction -ExportFormat JSON -EmailReport -Credential (Get-Credential)
```

**ROI Impact:** Eliminates manual server inventory maintenance, ensures comprehensive coverage

#### CI/CD Pipeline Integration
```yaml
# Azure DevOps Pipeline Example
- task: PowerShell@2
  displayName: 'Infrastructure Health Check'
  inputs:
    targetType: 'inline'
    script: |
      $result = Get-ModuleFunction -ComputerName $env:SERVERS -Threshold 85 -PassThru
      if ($result | Where-Object HealthStatus -eq 'Critical') {
        Write-Error "Critical issues detected. Deployment aborted."
        exit 1
      }
```

#### Scheduled Automation with Error Handling
```powershell
# Enterprise scheduled monitoring with comprehensive error handling
try {
    $servers = Get-Content ".\ServerLists\ProductionServers.txt"
    $results = Get-ModuleFunction -ComputerName $servers -ExportFormat Excel -EmailReport

    Write-EventLog -LogName Application -Source "ModuleName" -EventId 1000 -EntryType Information -Message "Monitoring completed: $($servers.Count) servers processed"
}
catch {
    Write-EventLog -LogName Application -Source "ModuleName" -EventId 1001 -EntryType Error -Message "Monitoring failed: $($_.Exception.Message)"
    Send-MailMessage -To "alerts@company.com" -Subject "🚨 Monitoring Alert" -Body $_.Exception.Message
}
```
```

#### 🔍 Troubleshooting Section
Comprehensive problem-solving guidance:

```markdown
## 🔍 Troubleshooting

### Quick Diagnostics
```powershell
# Built-in health check and diagnostics
Test-ModuleHealth -Verbose -ExportDiagnostics
```

### Common Issues

<details>
<summary>❌ "Access Denied" or Permission Errors</summary>

**Symptoms:** Script fails with "Access is denied" or authentication errors

**Root Causes:**
1. Insufficient user privileges on target systems
2. WinRM not enabled or configured
3. Firewall blocking required ports
4. Credential delegation issues

**Solutions:**
```powershell
# Test connectivity and permissions
Test-WSMan -ComputerName "SERVER01" -Credential (Get-Credential)

# Enable WinRM on target servers (run as administrator)
Enable-PSRemoting -Force
Set-WSManQuickConfig -Force
```

**Related Documentation:** [Security Configuration Guide](./Troubleshooting/Security/WinRM-Setup.md)

</details>

<details>
<summary>⚠️ Performance Issues or Timeouts</summary>

**Symptoms:** Slow execution, timeout errors, high memory usage

**Diagnostic Commands:**
```powershell
# Enable detailed performance logging
Get-ModuleFunction -ComputerName $servers -Verbose -Debug -PerformanceLogging

# Monitor resource usage
Get-Process -Name powershell | Select-Object CPU, WorkingSet, VirtualMemorySize
```

**Optimization Strategies:**
```powershell
# Process servers in batches for large environments
$serverBatches = $allServers | Group-Object {[math]::Floor($_.ReadCount / 10)}
foreach ($batch in $serverBatches) {
    Get-ModuleFunction -ComputerName $batch.Group -ExportFormat JSON
    Start-Sleep -Seconds 30
}
```

**Related Documentation:** [Performance Optimization Guide](./Troubleshooting/Performance/Large-Scale-Operations.md)

</details>

### Error Code Reference
| Error Code | Description | Immediate Action | Documentation |
|------------|-------------|------------------|---------------|
| **E001** | Connection timeout | Verify network connectivity and WinRM | [Connectivity Guide](./Troubleshooting/Connectivity/) |
| **E002** | Authentication failure | Check credentials and permissions | [Security Setup](./Troubleshooting/Security/) |
| **E003** | Invalid parameter format | Review parameter syntax and examples | [Usage Examples](#-usage) |

### Self-Diagnostic Tools
```powershell
# Comprehensive environment validation
Test-ModuleEnvironment -IncludeNetworkTest -IncludePermissionTest -ExportReport
```
```

#### Performance & Monitoring Section
Document performance characteristics and monitoring integration:

```markdown
## 📊 Performance & Monitoring

### Performance Characteristics
| Environment Size | Execution Time | Memory Usage | Recommended Approach |
|------------------|----------------|--------------|---------------------|
| **Small (1-10 servers)** | 2-5 minutes | <100MB | Standard execution |
| **Medium (10-50 servers)** | 10-20 minutes | 100-500MB | Chunked processing |
| **Large (50+ servers)** | 20+ minutes | 500MB+ | Parallel processing |

### Monitoring Integration
- **Application Insights**: Telemetry and performance tracking
- **SCOM Integration**: Enterprise monitoring system compatibility
- **Custom Dashboards**: Power BI and Grafana integration examples
- **Alerting**: Integration with PagerDuty, ServiceNow, and email systems

### Optimization Guidelines
```powershell
# PowerShell 7.x parallel processing
$servers | ForEach-Object -Parallel {
    Get-ModuleFunction -ComputerName $_ -ExportFormat JSON
} -ThrottleLimit 5

# Memory-efficient processing for large datasets
$servers | ForEach-Object {
    Get-ModuleFunction -ComputerName $_ -StreamOutput
} | Export-Csv "results.csv" -NoTypeInformation
```
```

## Quality Assurance Integration

### Documentation Validation
Ensure README meets enterprise standards:

#### Content Verification Checklist
- [ ] Business value clearly articulated in overview
- [ ] All prerequisites documented with specific versions
- [ ] Installation instructions tested on clean environment
- [ ] Configuration examples validated and functional
- [ ] Usage examples copy-paste ready and tested
- [ ] Troubleshooting section addresses common issues
- [ ] Performance characteristics measured and documented
- [ ] Integration with `./Troubleshooting/` folder structure maintained

#### Technical Accuracy Standards
- [ ] All code examples executed and output verified
- [ ] Links reference existing files and documentation
- [ ] Version numbers current and consistent
- [ ] Dependencies list complete and accurate
- [ ] Error codes match actual script output
- [ ] Performance metrics realistic and measured

#### Accessibility and Usability
- [ ] Table of contents functional and complete
- [ ] Heading hierarchy logical and consistent
- [ ] Language appropriate for target audience
- [ ] Examples progress from simple to complex
- [ ] Mobile-friendly formatting considerations

## Enhanced Features

### Interactive Elements
Add collapsible sections for detailed information:

```markdown
<details>
<summary>🔧 Advanced Configuration Options</summary>

### Enterprise Security Settings
```json
{
  "security": {
    "encryptionRequired": true,
    "certificateValidation": "strict",
    "auditLogging": true,
    "sessionTimeout": 3600
  }
}
```

**Security Note:** These settings affect compliance and should be reviewed by security teams.

</details>
```

### Visual Enhancements
- **Status badges** for build, version, downloads, and coverage
- **Emoji icons** for section headers and visual navigation
- **Code syntax highlighting** with language specification
- **Tables** for structured information presentation
- **Mermaid diagrams** for workflow and architecture visualization

### Business Integration
- **ROI calculations** and cost-benefit analysis
- **Compliance mapping** to regulatory requirements
- **Executive summary** sections for management audiences
- **Success metrics** and KPI tracking integration

Generate comprehensive README documentation that serves multiple audiences, provides immediate value through quick start sections, includes thorough troubleshooting guidance with proper references to `./Troubleshooting/` folder structure, and maintains consistency with enterprise PowerShell development standards.