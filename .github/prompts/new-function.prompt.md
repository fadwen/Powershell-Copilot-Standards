---
mode: 'agent'
description: 'Creates enterprise-standard PowerShell function'
tools: ['codebase']
---

Create a PowerShell function for the ${workspaceFolderBasename} project in ${fileBasename}:

**Function Specifications:**
- **Name**: ${input:functionName:Get-Something}
- **Purpose**: ${input:purpose:Describe what this function accomplishes for the business}
- **Parameters**: ${input:parameters:List the main parameters (name:type:description)}
- **Pipeline Support**: ${input:pipelineSupport:Yes}
- **Returns**: ${input:returnType:PSCustomObject}

**Enterprise Requirements:**
- Use approved PowerShell verb from Get-Verb
- Include comprehensive comment-based help with business value
- Implement proper parameter validation with [ValidateNotNullOrEmpty()]
- Add error handling with correlation IDs
- Include SupportsShouldProcess if making changes
- Reference troubleshooting docs in .\Troubleshooting\

**Additional Context:**
- Target PowerShell version: ${input:psVersion:5.1+}
- Include basic Pester tests: ${input:includeTests:Yes}

Generate the complete function implementation following our enterprise standards.
