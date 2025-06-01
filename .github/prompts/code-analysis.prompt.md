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
- Efficient collection handling (avoid array += in loops)
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
```

## optimize-performance.prompt.md
```markdown
---
mode: 'agent'
description: 'Performance optimization with context-aware recommendations'
---

Analyze and optimize PowerShell code performance:

**Code to Optimize:**
```powershell
${selection}
```

**Performance Context:**
- Data scale: ${input:dataScale:Small (<1K items),Medium (1K-100K),Large (>100K):Medium}
- Performance target: ${input:target:Optimize for readability,Optimize for speed,Balance both:Balance both}
- PowerShell version: ${input:psVersion:5.1,7.x:7.x}
- Environment: ${input:environment:Development,Testing,Production:Production}

**Analysis Areas:**

**1. Context-Appropriate String Operations ✅**
- Small operations: Simple concatenation acceptable
- Large/repeated operations: StringBuilder or -join
- Template strings vs concatenation efficiency
- Memory allocation patterns

**2. Collection Handling ✅**
- Avoid array += in loops for large datasets
- Use appropriate collection types (ArrayList, List<T>, etc.)
- Pipeline vs foreach performance trade-offs
- Memory-efficient processing patterns

**3. Modern PowerShell Features ✅**
- Leverage PowerShell 7.x performance improvements
- Use efficient cmdlets and operators
- Take advantage of parallel processing where appropriate
- Optimize pipeline usage

**4. Algorithm Efficiency ✅**
- Identify O(n²) operations
- Optimize filtering and searching
- Reduce redundant operations
- Improve data structure choices

**5. Resource Management ✅**
- Memory usage optimization
- Proper disposal patterns
- Efficient file I/O operations
- Network call optimization

**Optimization Strategy:**
Based on data scale and target, provide:
- 🚀 High-impact optimizations
- ⚖️ Performance vs readability trade-offs
- 📊 Expected performance improvements
- 🔧 Specific code corrections
- 📋 Benchmarking recommendations

Include before/after examples with performance impact estimates.