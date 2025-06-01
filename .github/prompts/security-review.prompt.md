---
mode: 'edit'
description: 'Security analysis with modern PowerShell patterns'
---

Perform comprehensive security analysis on this PowerShell code:

**Selected Code:**
```powershell
${selection}
```

**Analysis Context:**
- Compliance framework: ${input:complianceFramework:SOX,GDPR,HIPAA,PCI-DSS,General:General}
- Environment: ${input:environment:Development,Testing,Production:Production}
- File: ${fileBasename}
- Project: ${workspaceFolderBasename}

**Security Review Areas:**

1. **Modern Credential Handling**
   - Check for [PSCredential]::new() usage vs legacy New-Object
   - Validate SecureString implementation
   - Identify hardcoded credentials or API keys

2. **Input Validation**
   - Verify appropriate parameter validation (not over-validated)
   - Check for SQL injection in dynamic queries
   - Validate file path and command injection risks

3. **Error Handling Security**
   - Ensure $_ usage in catch blocks (not $Error manipulation)
   - Check for information disclosure in error messages
   - Validate proper exception propagation

4. **Enterprise Security Patterns**
   - Audit trail implementation with correlation IDs
   - Access control and privilege verification
   - Data encryption and protection patterns

5. **Compliance Alignment**
   - Framework-specific requirements validation
   - Data handling and retention compliance
   - Security logging and monitoring requirements

Provide specific remediation recommendations with corrected code examples following modern PowerShell best practices.