---
mode: 'edit'
description: 'Comprehensive security analysis with compliance focus'
---

Perform security analysis on this PowerShell code from ${fileBasename}:

**Selected Code:**
```powershell
${selection}
```

**Security Analysis Scope:**
- **Compliance Framework**: ${input:complianceFramework:SOX,GDPR,HIPAA,PCI-DSS,General}
- **Environment**: ${input:environment:Production,Development,Testing}
- **Risk Tolerance**: ${input:riskLevel:Low,Medium,High}

**Analysis Areas:**
1. **Input Validation**: Check for proper validation and sanitization
2. **Credential Security**: Verify no hardcoded credentials or secrets
3. **Injection Prevention**: Look for potential code injection vulnerabilities
4. **Path Security**: Validate file path handling and prevent traversal attacks
5. **Security Logging**: Ensure security events are properly logged with correlation IDs
6. **Compliance Alignment**: Verify alignment with ${input:complianceFramework} requirements

**Output Requirements:**
- List specific vulnerabilities found with severity levels
- Provide remediation code examples
- Reference relevant troubleshooting documentation in .\Troubleshooting\Security\
- Include compliance validation steps

Generate specific, actionable security recommendations for ${workspaceFolderBasename} project.
