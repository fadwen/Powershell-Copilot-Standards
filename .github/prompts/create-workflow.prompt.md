---
mode: 'agent'
description: 'Generates business workflow automation'
tools: ['codebase']
---

Create PowerShell workflow automation for ${workspaceFolderBasename}:

**Workflow Details:**
- **Business Process**: ${input:process:Describe the business process to automate}
- **Trigger Type**: ${input:trigger:Scheduled,Event-driven,Manual,API-triggered}
- **Integration Points**: ${input:integrations:Active Directory,Database,Email,REST APIs,File System}
- **Error Handling**: ${input:errorHandling:Email notifications,ServiceNow tickets,Database logging,All}

**Workflow Components to Generate:**
1. **Main orchestration function** with comprehensive error handling
2. **Individual process steps** as reusable functions
3. **Configuration management** for environment-specific settings
4. **Logging and monitoring** integration
5. **Rollback and recovery** procedures
6. **Testing framework** for workflow validation

**Enterprise Requirements:**
- Include correlation ID tracking throughout workflow
- Implement approval gates for production changes
- Generate audit trails for compliance requirements
- Include performance monitoring and alerting