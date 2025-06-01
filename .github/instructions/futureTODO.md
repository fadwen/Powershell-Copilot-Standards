# .instructions.md (Place in specific project folders)
---
applyTo: "**/*.ps1,**/*.psm1"
---

# Project-Specific PowerShell Standards

## Infrastructure Automation Project Context
This project focuses on enterprise infrastructure automation with these specific requirements:

### Domain-Specific Patterns
- **Server Management**: All functions must support bulk operations with progress reporting
- **Active Directory Integration**: Use specific organizational units: "OU=Servers,DC=contoso,DC=com"
- **Monitoring Integration**: Include SCOM integration hooks and custom performance counters
- **Change Management**: All infrastructure changes require approval workflow integration

### Project-Specific Validation
```powershell
# Server name validation for this environment
[ValidatePattern('^(WEB|DB|APP|DC)\d{2}$')]
[string]$ServerName

# Environment validation
[ValidateSet('DEV', 'TEST', 'STAGE', 'PROD')]
[string]$Environment
```

### Required Error Codes
- **E1001**: Server connectivity failure
- **E1002**: Active Directory operation failed
- **E1003**: SCOM integration error
- **E1004**: Change management approval required

### Integration Requirements
- **ServiceNow**: Include ticket correlation in all operations
- **SCOM**: Custom event logging for infrastructure changes
- **Email Notifications**: Use template system for consistent formatting
- **Database Logging**: Store all operations in AuditDB.InfrastructureOps table

# security-project.instructions.md
---
applyTo: "**/*security*.ps1,**/*compliance*.ps1"
---

# Security & Compliance Project Standards

This project handles sensitive security data and must meet SOX compliance requirements.

### Mandatory Security Controls
- **Data Classification**: All functions must handle data classification metadata
- **Audit Logging**: Every operation requires comprehensive audit trails
- **Encryption**: All data at rest and in transit must be encrypted
- **Access Controls**: Role-based access validation required

### Compliance Framework Integration
```powershell
# SOX compliance validation
function Invoke-SOXValidation {
    param([string]$Operation, [string]$BusinessJustification)
    # Implementation required for all financial data operations
}

# GDPR consent verification
function Test-GDPRConsent {
    param([string]$DataSubjectId, [string]$ProcessingPurpose)
    # Required for all personal data processing
}
```