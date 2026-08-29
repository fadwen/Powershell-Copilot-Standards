---
mode: 'edit'
applyTo: "**/*.ps1,**/*.psm1"
description: 'Defines help content standards for PowerShell functions - comment-based help and PlatyPS Markdown'
---

# PowerShell Help Content Standards

Generate comprehensive, enterprise-grade help for PowerShell functions that serves as both technical
documentation and business communication. Create help that supports automatic README generation and provides full
`Get-Help` functionality.

## Where Help Lives

This file defines **what good help content contains**. Where that content is written depends on
whether the function is exported:

| Function | Help lives in | Notes |
|---|---|---|
| Exported (`Public/`) in a module | PlatyPS Markdown under `docs/ModuleName/` | The `.ps1` keeps only `# .EXTERNALHELP` plus a one-line `.SYNOPSIS` |
| Private (`Private/`) in a module | Full comment-based help in the `.ps1` | PlatyPS never sees these - the comment block is the only documentation |
| Standalone script or function | Full comment-based help in the `.ps1` | No module, no MAML, no PlatyPS |

Every standard below — description structure, per-parameter content, three progressive examples,
enterprise notes — applies in all three cases. Only the file it is typed into changes.

For the generation, update, and build mechanics, see
[platyps.instructions.md](./platyps.instructions.md). Do not add detail to a public function's
comment block: `.EXTERNALHELP` makes `Get-Help` ignore it, so the effort is invisible to users and
becomes a second copy that drifts.

## Help Generation Requirements

> **Worked example**:
> [Basic-Function-Example.ps1](../../Documentation/Examples/Basic-Function-Example.ps1) carries a
> complete help block in the form described here - synopsis, description, per-parameter text,
> multiple examples with expected output, and `.NOTES` with troubleshooting links but no change
> history. It is a standalone function, so the whole block lives in the `.ps1`. In a module, that
> same content is what belongs in the command's Markdown file.

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
    PowerShell Version: 7.6 (LTS), or Windows PowerShell 5.1

    No change history here - git records it, and a hand-maintained log in .NOTES
    goes stale the first time someone forgets to update it.

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
- [ ] No change history in .NOTES - version control already records it
- [ ] Cross-platform compatibility notes where applicable
- [ ] Content is in the right file: Markdown under `docs/` for exported functions, the `.ps1` comment
      block for private functions and standalone scripts
- [ ] Public functions carry `.EXTERNALHELP <ModuleName>-Help.xml` and no duplicated detail in the
      comment block

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

### Keyword to Markdown Mapping

The sections above are named for comment-based help keywords. In PlatyPS Markdown they are headings.
The content requirements are identical; only the syntax differs:

| Comment-based help | PlatyPS Markdown |
|---|---|
| `.SYNOPSIS` | `## SYNOPSIS` |
| `.DESCRIPTION` | `## DESCRIPTION` |
| `.PARAMETER Name` | `### -Name` under `## PARAMETERS` |
| `.EXAMPLE` | `### Example 1: <title>` under `## EXAMPLES` |
| `.INPUTS` / `.OUTPUTS` | `## INPUTS` / `## OUTPUTS` |
| `.NOTES` | `## NOTES` |
| `.LINK` | `## RELATED LINKS` |
| _(no equivalent)_ | `## ALIASES` - Markdown only; delete the section if the command has none |

Parameter attribute tables, syntax blocks, and the common-parameter block are generated by PlatyPS
from the function definition. Never hand-write or hand-correct them in the Markdown — fix the
function signature and re-run `Update-MarkdownCommandHelp`.

### Enterprise Standards Compliance

- Reference established PowerShell development standards
- Include correlation ID usage examples
- Document integration with organizational monitoring systems
- Maintain consistency with troubleshooting documentation structure

When generating help content, always follow the enterprise PowerShell development standards and ensure all
troubleshooting references point to properly organized documentation in the `./Troubleshooting/` folder structure.
Write that content into the PlatyPS Markdown for exported functions and into the comment block for
everything else - see [platyps.instructions.md](./platyps.instructions.md).
