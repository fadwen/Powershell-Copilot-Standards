---
mode: 'agent'
description: 'Comprehensive code quality analysis with expert-reviewed standards'
tools: ['codebase']
---

Perform thorough analysis of this PowerShell code against modern best practices:

**Selected Code:**

```powershell
${selection}
```

**Analysis Framework:**

**1. Modern PowerShell Patterns ✅**

- Error handling: Verify $_ usage in catch blocks (not $Error[0])
- Credential creation: Check for [PSCredential]::new() vs New-Object
- Parameter validation: Ensure appropriate validation without redundancy
- String operations: Context-appropriate concatenation vs StringBuilder

**2. Comment-Based Help Quality ✅**

- Proper block comment syntax with opening markers
- Complete parameter documentation
- Meaningful examples with descriptions
- Appropriate .INPUTS and .OUTPUTS sections
- Avoid maintenance-heavy versioning in .NOTES

**3. Performance Patterns ✅**

- Context-aware string operations (simple vs complex)
- Collection handling: flag `+=` only where the declared target is below 7.5, in which it is still
  O(n²), or where the loop is unbounded. PowerShell 7.5 optimised it. Never suggest `ArrayList`
- Appropriate use of pipeline vs loops
- Memory-conscious patterns for large datasets

**4. Output Type Design ✅**

- Descriptive type names instead of misleading [PSCustomObject]
- Custom classes for complex objects
- Meaningful IntelliSense support
- Proper type declarations

**5. Enterprise Standards ✅**

- Correlation ID implementation
- Structured logging patterns
- Configuration-driven behavior
- Environment-appropriate error handling

**6. Security & Compliance ✅**

- Modern security patterns
- Input validation best practices
- Audit trail requirements
- Compliance framework alignment

**7. Code Quality Metrics ✅**

- Approved PowerShell verb usage
- Consistent style and formatting
- Appropriate function complexity
- Clear separation of concerns

**Analysis Output:**
Provide prioritized recommendations with:

- ❌ Issues found with severity rating
- ✅ Best practices already implemented
- 🔧 Specific code corrections
- 💡 Optimization opportunities
- 📋 Compliance gaps

Include corrected code examples demonstrating proper modern PowerShell patterns.
