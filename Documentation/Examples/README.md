# ExampleModule - Enterprise PowerShell Module

## Overview
ExampleModule demonstrates enterprise-grade PowerShell development following established community standards and organizational requirements. This module serves as both a functional tool and a reference implementation for the [PowerShell Copilot Standards](https://github.com/EntraVantage/PowerShell-Copilot-Standards).

## Features
- ✅ **User Management**: Comprehensive Active Directory integration
- ✅ **Security Auditing**: SOX, GDPR, HIPAA compliance validation
- ✅ **Performance Monitoring**: System performance metrics and alerting
- ✅ **Configuration Management**: Environment-specific settings and baselines
- ✅ **Correlation Tracking**: End-to-end operation tracking for troubleshooting
- ✅ **Modern PowerShell**: Compatible with PowerShell 5.1+ and PowerShell 7+

## Installation

### From PowerShell Gallery
```powershell
Install-Module -Name ExampleModule -Repository PSGallery -Scope CurrentUser
```

### From Source
```powershell
# Clone the repository
git clone https://github.com/EntraVantage/ExampleModule.git

# Import the module
Import-Module .\ExampleModule\ExampleModule.psd1
```

## Quick Start

### Basic User Data Retrieval
```powershell
# Get user information with group memberships
$userData = Get-UserData -UserName "john.doe" -IncludeGroups

# Display results
$userData | Format-Table Name, Department, LastLogon, GroupCount
```

### Security Compliance Audit
```powershell
# Run comprehensive security audit
$auditResults = Invoke-SecurityAudit -Scope "ActiveDirectory" -ComplianceFramework "SOX"

# Generate compliance report
$auditResults | Export-Csv -Path ".\SOX-Audit-$(Get-Date -Format 'yyyy-MM-dd').csv"
```

### System Performance Monitoring
```powershell
# Get performance metrics with correlation tracking
$metrics = Get-PerformanceMetrics -ComputerName "SERVER01" -IncludeHistory

# Set performance baseline for environment
Set-ConfigurationBaseline -Environment "Production" -PerformanceThreshold 1000
```

## Function Reference

### User Management Functions
- **Get-UserData**: Retrieve comprehensive user information from Active Directory
- **Set-UserPermissions**: Modify user permissions with audit trail
- **New-ServiceAccount**: Create service accounts following security standards
- **Remove-StaleAccounts**: Identify and remove inactive user accounts

### Security and Compliance Functions
- **Invoke-SecurityAudit**: Comprehensive security assessment with compliance reporting
- **Test-SystemCompliance**: Validate system configuration against compliance frameworks

### Performance and Monitoring Functions
- **Get-PerformanceMetrics**: Collect and analyze system performance data
- **Set-ConfigurationBaseline**: Establish performance and security baselines

## Configuration

### Environment-Specific Settings
The module supports three deployment environments with different security and performance profiles:

#### Development Environment
```powershell
$config = @{
    LogLevel = 'Verbose'
    TimeoutSeconds = 30
    SecurityValidation = 'Relaxed'
    PerformanceThreshold = 5000
}
```

#### Production Environment
```powershell
$config = @{
    LogLevel = 'Minimal'
    TimeoutSeconds = 10
    SecurityValidation = 'Strict'
    PerformanceThreshold = 1000
}
```

### Security Configuration
All functions support enterprise security requirements:

- **Kerberos Authentication**: Default authentication method
- **Certificate-Based Auth**: For high-security scenarios
- **Correlation ID Tracking**: Every operation includes correlation IDs
- **Audit Trail Logging**: Complete audit trails for compliance

## Quality Standards

This module follows the [PowerShell Copilot Standards](https://github.com/EntraVantage/PowerShell-Copilot-Standards) including:

### Code Quality Requirements
- ✅ **PSScriptAnalyzer**: Zero errors, minimal warnings
- ✅ **Pester Testing**: 80%+ code coverage requirement
- ✅ **Approved Verbs**: Only Microsoft-approved PowerShell verbs
- ✅ **Security Scanning**: No hardcoded credentials or vulnerabilities
- ✅ **Performance Standards**: Optimized for enterprise scale

### Expert Feedback Integration
Recent updates incorporate expert PowerShell feedback:

- **Error Handling**: Use `$_` in catch blocks instead of `$Error[0]`
- **String Operations**: Context-appropriate concatenation vs StringBuilder
- **Modern PowerShell**: Use `[PSCredential]::new()` instead of New-Object
- **Parameter Validation**: Validate before downstream function usage
- **Security Patterns**: No Basic Authentication, prefer Kerberos/Certificate auth

## Examples

### Advanced User Management
```powershell
# Complex user provisioning with correlation tracking
$correlationId = [System.Guid]::NewGuid().ToString()

# Create service account with proper security
$serviceAccount = New-ServiceAccount -Name "svc-webapp" -Department "IT" -CorrelationId $correlationId

# Set permissions with audit trail
Set-UserPermissions -UserName $serviceAccount.SamAccountName -Permissions @("LogonAsService", "NetworkAccess") -CorrelationId $correlationId

# Verify compliance
$complianceResult = Test-SystemCompliance -UserName $serviceAccount.SamAccountName -Framework "SOX" -CorrelationId $correlationId
```

### Performance Monitoring with Alerting
```powershell
# Monitor multiple servers with baseline comparison
$servers = @("WEB01", "WEB02", "DB01")
$performanceData = @()

foreach ($server in $servers) {
    $metrics = Get-PerformanceMetrics -ComputerName $server -IncludeBaseline
    $performanceData += $metrics

    # Alert on threshold violations
    if ($metrics.ResponseTime -gt $metrics.Baseline.Threshold) {
        Send-Alert -Type "Performance" -Server $server -Metrics $metrics
    }
}

# Generate performance report
$performanceData | Export-Excel -Path ".\Performance-Report-$(Get-Date -Format 'yyyy-MM-dd').xlsx"
```

## Contributing

### Development Standards
All contributions must meet enterprise quality standards:

1. **Quality Gates**: All PRs must pass automated quality checks
2. **Code Review**: Require approval from @fadwen or @ev-jeffs
3. **Testing**: Include Pester tests with 80%+ coverage
4. **Documentation**: Update help documentation and examples
5. **Security**: Pass security scanning and validation

### Branch Protection
The main branch is protected with required status checks:
- PowerShell Quality Gates
- Security Scan
- Documentation Quality
- Code Owner Review

### Getting Started with Development
```powershell
# Clone the repository
git clone https://github.com/EntraVantage/ExampleModule.git
cd ExampleModule

# Create feature branch
git checkout -b feature/your-feature-name

# Make changes following PowerShell standards
# Run quality checks locally
.\Tools\Test-StandardsCompliance.ps1 -Path "." -Detailed

# Create pull request when ready
```

## Troubleshooting

### Common Issues

#### Authentication Failures
```powershell
# Verify Kerberos configuration
Test-WSMan -ComputerName $targetServer -Authentication Kerberos

# Check credential delegation
Get-WSManCredSSP
```

#### Performance Issues
```powershell
# Check current performance baselines
Get-PerformanceMetrics -ComputerName "localhost" -ShowBaseline

# Analyze correlation IDs for slow operations
Search-CorrelationLog -CorrelationId $correlationId -ShowTimeline
```

#### Compliance Validation Failures
```powershell
# Run detailed compliance check
Test-SystemCompliance -Framework "SOX" -Detailed -Verbose

# Review audit log for compliance events
Get-AuditLog -Category "Compliance" -TimeRange (Get-Date).AddDays(-7)
```

### Support Resources
- **Documentation**: [Enterprise PowerShell Docs](https://docs.entravantage.com/powershell)
- **Troubleshooting**: [Common Issues Guide](./Troubleshooting/README.md)
- **Security**: [Security Configuration Guide](./Documentation/Security-Configuration.md)
- **Performance**: [Performance Optimization Guide](./Documentation/Performance-Optimization.md)

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog
See [CHANGELOG.md](CHANGELOG.md) for detailed version history and breaking changes.

---

**Quality Standards**: This module follows [PowerShell Copilot Standards](https://github.com/EntraVantage/PowerShell-Copilot-Standards) for enterprise PowerShell development.

**Support**: For enterprise support, contact powershell-support@entravantage.com