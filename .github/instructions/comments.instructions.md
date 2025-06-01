---
mode: 'edit'
applyTo: "**/*.ps1,**/*.psm1"
description: 'Generates comprehensive comment-based help for PowerShell functions following enterprise standards'
---

# PowerShell Comment-Based Help Generator

Generate comprehensive, enterprise-grade comment-based help for PowerShell functions that serves as both technical documentation and business communication. Create help that supports automatic README generation and provides full `Get-Help` functionality.

## Help Generation Requirements

### Mandatory Sections
Generate complete comment-based help including all required sections:

#### .SYNOPSIS
- Use approved PowerShell verbs (Get, Set, New, Remove, etc.)
- Maximum 80 characters
- Focus on primary action and business value
- Avoid technical jargon unless necessary

#### .DESCRIPTION
Structure with multiple audiences in mind:
- **Core Functionality**: Primary purpose and key features
- **Business Value**: Why this function exists and organizational benefits
- **Use Cases**: Common scenarios and applications
- **Dependencies**: Required modules, permissions, and system requirements
- **Performance Considerations**: Expected execution time and resource usage
- **Side Effects**: Any system or environment changes

#### .PARAMETER
For each parameter, provide:
- **Data Type**: Explicit .NET type with constraints
- **Mandatory Status**: Clear indication if required
- **Pipeline Support**: ByValue, ByPropertyName capabilities
- **Validation Rules**: Constraints, acceptable values, patterns
- **Business Context**: Why this parameter exists and when to use it
- **Examples**: Sample valid values and usage patterns

#### .EXAMPLE
Provide minimum three progressive examples:
1. **Basic Usage**: Simplest functional example with expected output
2. **Advanced Scenario**: Multiple parameters with real-world context
3. **Pipeline Integration**: Shows integration with other PowerShell commands

For each example include:
- Clear description of the scenario
- Expected output or behavior
- Business use case or context
- Duration estimates where relevant

#### .INPUTS/.OUTPUTS
- Document .NET types for pipeline compatibility
- Describe object structure and properties
- Include usage guidance for returned objects
- Specify when different output types are returned

#### .NOTES
Comprehensive metadata including:
- **Author Information**: Name, blog, LinkedIn
- **Version History**: Changes with dates and descriptions
- **Security Considerations**: Permissions, data handling, compliance notes
- **Performance Characteristics**: Benchmarks and optimization notes
- **Troubleshooting References**: Links to documentation in `./Troubleshooting/` folder
- **Known Limitations**: Current constraints and workarounds

#### .LINK
Include relevant reference links:
- Online documentation URLs
- Related function references
- Microsoft documentation links
- Troubleshooting guides in `./Troubleshooting/` folder
- Enterprise standards documentation

## Help Content Standards

### Business-Focused Language
- Articulate clear business value in DESCRIPTION
- Use business scenarios in examples
- Explain ROI and organizational impact
- Reference compliance and governance benefits

### Technical Accuracy
- Validate all code examples are functional
- Ensure parameter descriptions match actual validation
- Verify .NET types are correct
- Test all usage examples before documenting

### Enterprise Integration
- Reference correlation ID usage for tracing
- Document integration with organizational systems
- Include security and compliance considerations
- Reference established troubleshooting procedures

### Performance Documentation
- Include typical execution times
- Document memory usage characteristics
- Specify scalability considerations
- Provide optimization recommendations

## Enhanced Help Patterns

### Complex Parameter Documentation
```powershell
.PARAMETER ComputerName
    [String[]] (Mandatory: Yes, Pipeline: ByValue, ByPropertyName)

    Specifies one or more target computer names for data collection.

    VALIDATION RULES:
    - Must be valid computer names (NetBIOS or FQDN)
    - Maximum 50 computers per execution
    - Computers must be reachable via WinRM

    BUSINESS CONTEXT:
    Used to target specific servers for monitoring. Consider grouping
    servers by function (web servers, database servers) for meaningful reports.

    EXAMPLES:
    - Single server: "SERVER01"
    - Multiple servers: "SERVER01", "SERVER02", "SERVER03"
    - Domain servers: "server01.contoso.com"
```

### Comprehensive Example Format
```powershell
.EXAMPLE
    PS> Get-ServerHealth -ComputerName "SERVER01" -IncludePerformance

    DESCRIPTION: Basic health check with performance metrics
    OUTPUT: Health status object with CPU, memory, and disk information
    DURATION: Approximately 30 seconds
    USE CASE: Daily server health verification during morning checks

.EXAMPLE
    PS> Get-ADComputer -Filter "OperatingSystem -like '*Server*'" |
         Select-Object -ExpandProperty Name |
         Get-ServerHealth -Threshold 80 -ExportReport

    DESCRIPTION: Enterprise pipeline integration with Active Directory
    OUTPUT: Health reports for all domain servers with alerting
    BUSINESS CASE: Automated infrastructure monitoring and compliance reporting
    INTEGRATION: Combines AD discovery with health monitoring
```

### Enterprise Notes Section
```powershell
.NOTES
    Author: Jeffrey Stuhr
    Blog: https://www.techbyjeff.net
    LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/
    Last Updated: $(Get-Date -Format 'yyyy-MM-dd')
    Version: 2.1.0
    PowerShell Version: 5.1+ (Windows), 7.x+ (Cross-platform)

    CHANGE HISTORY:
    v2.1.00 (2024-01-15) - Added JSON export and email reporting
    v2.0.00 (2023-12-01) - BREAKING: Changed output format, added pipeline support
    v1.5.11 (2023-11-15) - Fixed syntax errors in examples, improved performance metrics
    v1.5.10 (2023-11-15) - Fixed memory leak in long-running operations

    SECURITY CONSIDERATIONS:
    - Requires local administrator privileges on target servers
    - Uses WinRM for remote connectivity (ensure proper firewall configuration)
    - Performance data may contain sensitive infrastructure information
    - Credential handling follows secure PowerShell practices

    PERFORMANCE CHARACTERISTICS:
    - Linear scaling: approximately 20-30 seconds per server
    - Memory footprint: ~5MB per server in monitoring queue
    - Network bandwidth: minimal (WMI query overhead only)

    TROUBLESHOOTING RESOURCES:
    - Connectivity issues: .\Troubleshooting\Connectivity\WinRM-Configuration.md
    - Performance problems: .\Troubleshooting\Performance\Large-Scale-Monitoring.md
    - Security errors: .\Troubleshooting\Security\Admin-Rights-Setup.md

    COMPLIANCE NOTES:
    - SOX compliance: Audit trail maintained in structured logs
    - GDPR considerations: Performance data may contain system identifiers
    - Data retention: Follows organizational policy (default: 90 days)
```

## Quality Validation

### Content Verification Checklist
Ensure generated help includes:
- [ ] Business value clearly articulated in .DESCRIPTION
- [ ] All parameters documented with validation rules and business context
- [ ] Minimum 3 examples with progressive complexity
- [ ] Performance characteristics documented
- [ ] Security considerations comprehensive
- [ ] Troubleshooting references point to `./Troubleshooting/` folder
- [ ] Version history and change management information
- [ ] Cross-platform compatibility notes where applicable

### Technical Accuracy Validation
- [ ] All code examples tested and functional
- [ ] Parameter types and validation match function definition
- [ ] Output types accurately documented
- [ ] Links reference existing files and documentation
- [ ] Performance metrics realistic and measured

## Integration Requirements

### README Generation Support
Structure help to support automatic README generation:
- Clear section headings for extraction
- Business-focused language suitable for stakeholders
- Complete usage examples ready for documentation
- Integration scenarios for enterprise environments

### Get-Help Compatibility
Ensure full PowerShell Get-Help functionality:
- All standard help sections properly formatted
- Parameter help accessible via Get-Help -Parameter
- Examples displayable via Get-Help -Examples
- Detailed help available via Get-Help -Detailed

### Enterprise Standards Compliance
- Reference established PowerShell development standards
- Include correlation ID usage examples
- Document integration with organizational monitoring systems
- Maintain consistency with troubleshooting documentation structure

When generating comment-based help, always follow the enterprise PowerShell development standards and ensure all troubleshooting references point to properly organized documentation in the `./Troubleshooting/` folder structure.