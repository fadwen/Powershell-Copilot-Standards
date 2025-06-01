---
mode: 'edit'
description: 'Validates code against PowerShell community standards'
---

Validate this PowerShell code against established community best practices and style guidelines:

**Selected Code:**
```powershell
${selection}
```

**Validation Areas:**

## 🏗️ Best Practices Compliance
- **Tool Design**: Verify functions are reusable with parameter input and pipeline output
- **Error Handling**: Check for -ErrorAction Stop usage and proper try/catch blocks
- **Performance**: Identify array appending, string concatenation, and pipeline efficiency issues
- **Security**: Validate PSCredential usage and input sanitization
- **Modularity**: Assess function design and single responsibility principle

## 🎨 Style Guide Compliance
- **Code Layout**: One True Brace Style, 4-space indentation, 115-character lines
- **Naming**: Approved verbs, full command names, PascalCase conventions
- **Function Structure**: CmdletBinding, proper parameter validation, comment-based help
- **Formatting**: Operator spacing, parameter alignment, anti-pattern avoidance

## 📊 Analysis Output
Provide specific feedback on:
1. **Standards Violations**: List specific issues with line numbers
2. **Style Issues**: Formatting and naming problems
3. **Performance Concerns**: Anti-patterns and optimization opportunities
4. **Security Gaps**: Input validation and credential handling issues
5. **Corrected Code**: Show properly formatted version following all standards

**Focus on actionable recommendations** with before/after code examples that align with PowerShell community standards.