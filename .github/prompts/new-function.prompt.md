---
mode: 'agent'
description: 'Creates enterprise-standard PowerShell function with modern best practices'
tools: ['codebase']
---

Create a PowerShell function with these specifications:

**Function Details:**
- Function name: ${input:functionName:Verb-Noun}
- Purpose: ${input:purpose:Describe what this function accomplishes}
- Parameters needed: ${input:parameters:List the parameters and their types}
- Environment: ${input:environment:Development,Testing,Production:Development}

**Context:**
- Current file: ${fileBasename}
- Project: ${workspaceFolderBasename}
- PowerShell version: ${input:psVersion:5.1,7.x:7.x}

**Requirements:**
- Use modern PowerShell patterns (PSCredential::new(), $_ in catch blocks)
- Include proper comment-based help with complete syntax
- Implement appropriate parameter validation (avoid redundant validation)
- Use correlation IDs for enterprise logging
- Apply context-appropriate performance patterns
- Follow approved PowerShell verb usage
- Use descriptive output types instead of [PSCustomObject]

**Standards Compliance:**
- Error handling: Use $_ in catch blocks, not $Error[0]
- String operations: Context-appropriate (simple concatenation vs StringBuilder)
- Null handling: Simple null checks where appropriate, exceptions for operations that might fail
- Documentation: Complete comment-based help blocks
- Security: Modern credential handling patterns