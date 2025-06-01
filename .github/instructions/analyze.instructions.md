---
mode: 'agent'
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
tools: ['codebase', 'githubRepo']
description: 'Performs comprehensive PowerShell code analysis for quality, security, and performance'
---

# PowerShell Code Analysis

Analyze the provided PowerShell code using enterprise-grade analysis standards. Perform a comprehensive review covering code quality, security, performance, and compliance with organizational standards.

## Analysis Framework

Execute the following analysis components:

### 1. Code Quality Assessment
- **PSScriptAnalyzer Validation**: Check against all standard rules plus enterprise-specific rules
- **Best Practices Compliance**: Verify adherence to PowerShell development standards
- **Code Structure**: Evaluate function design, parameter validation, and pipeline efficiency
- **Documentation Quality**: Assess comment-based help completeness and accuracy

### 2. Security Analysis
- **Credential Leak Detection**: Scan for hardcoded passwords, API keys, or sensitive data
- **Input Validation**: Verify all user inputs are properly validated and sanitized
- **Path Traversal Protection**: Check for unsafe file path handling
- **Injection Prevention**: Identify potential code injection vulnerabilities

### 3. Performance Evaluation
- **Memory Usage**: Assess memory management and resource disposal
- **Pipeline Optimization**: Evaluate pipeline usage and efficiency
- **Scalability**: Review code for performance with large datasets
- **Algorithm Efficiency**: Identify optimization opportunities

### 4. Compliance Verification
- **PowerShell Standards**: Verify compliance with approved verbs and naming conventions
- **File Organization**: Check adherence to standardized folder structure
- **Testing Coverage**: Evaluate test completeness and quality
- **Error Handling**: Assess error handling patterns and correlation tracking

## Required Output Format

Provide analysis results in this structured format:

### 🚨 Critical Issues (Must Fix)
- List any critical security vulnerabilities or breaking errors
- Include specific line numbers and remediation steps

### ⚠️ High Priority Issues
- Security concerns that should be addressed before production
- Performance bottlenecks affecting scalability
- Standards violations impacting maintainability

### 📋 Medium Priority Recommendations
- Code quality improvements
- Performance optimizations
- Best practice adherence

### 💡 Low Priority Suggestions
- Style improvements
- Documentation enhancements
- Optional optimizations

### 📊 Analysis Summary
- Overall code quality score (1-100)
- Security risk level (Low/Medium/High/Critical)
- Performance rating (Poor/Fair/Good/Excellent)
- Standards compliance percentage

## Specific Checks to Perform

1. **Verify approved PowerShell verbs** are used for all functions
2. **Check for correlation IDs** in error handling and logging
3. **Validate parameter attributes** include proper validation
4. **Ensure troubleshooting documentation** references exist in `./Troubleshooting/` folder
5. **Confirm security practices** follow established patterns from copilot-instructions.md
6. **Review test coverage** and suggest missing test scenarios
7. **Check cross-platform compatibility** considerations

## Remediation Guidance

For each issue identified:
- Provide specific fix recommendations with code examples
- Reference relevant troubleshooting documentation in `./Troubleshooting/` folder
- Suggest appropriate test cases to validate fixes
- Include performance impact assessment where applicable

## Integration Notes

- Flag any violations of the standardized file organization structure
- Identify missing components (tests, documentation, error handling)
- Suggest improvements for CI/CD pipeline integration
- Recommend security scanning tools integration points

Focus on actionable feedback that improves code quality, security posture, and maintainability while ensuring compliance with enterprise PowerShell development standards.