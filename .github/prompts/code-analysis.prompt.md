---
mode: 'agent'
description: 'Comprehensive PowerShell code analysis and quality assessment'
tools: ['codebase', 'githubRepo']
---

Perform comprehensive analysis of this PowerShell code using enterprise standards:

## 🔍 Code Quality Analysis

### PowerShell Standards Compliance
- **Verb Usage**: Verify all functions use approved PowerShell verbs from Get-Verb
- **Naming Conventions**: Check PascalCase for functions, parameters, and variables
- **CmdletBinding**: Ensure all functions use [CmdletBinding()] attribute
- **Parameter Validation**: Validate comprehensive parameter attributes and validation
- **Help Documentation**: Assess comment-based help completeness and quality

### Best Practices Assessment
- **Error Handling**: Evaluate try/catch blocks and correlation ID usage
- **Pipeline Support**: Check ValueFromPipeline and process block implementation
- **Resource Management**: Verify IDisposable objects are properly disposed
- **Memory Efficiency**: Analyze string concatenation and collection handling
- **Performance Patterns**: Review algorithm efficiency and scalability

## 🛡️ Security Analysis

### Input Validation
- **Parameter Sanitization**: Check for proper input validation and sanitization
- **Path Traversal Prevention**: Validate file path handling security
- **Injection Prevention**: Scan for potential code injection vulnerabilities
- **Length Validation**: Ensure input length restrictions are implemented

### Credential Security
- **Hardcoded Secrets**: Scan for exposed passwords, API keys, or tokens
- **Secure Credential Handling**: Verify PSCredential and SecretManagement usage
- **Security Logging**: Check for appropriate security event logging

### Dangerous Patterns
- **Invoke-Expression Usage**: Flag dynamic code execution risks
- **COM Object Handling**: Verify proper cleanup and security measures
- **External Command Execution**: Assess command injection risks

## ⚡ Performance Evaluation

### Efficiency Patterns
- **Pipeline vs ForEach**: Analyze loop implementations for large datasets
- **Memory Allocation**: Check array initialization and growth patterns
- **String Operations**: Evaluate string concatenation methods
- **Resource Usage**: Assess CPU and memory consumption patterns

### Scalability Assessment
- **Data Volume Handling**: Evaluate performance with large datasets
- **Concurrent Processing**: Check for parallel processing opportunities
- **Resource Leaks**: Identify potential memory or handle leaks

## 🏗️ Architecture Quality

### Design Patterns
- **Single Responsibility**: Evaluate function focus and purpose clarity
- **Dependency Management**: Assess module dependencies and coupling
- **Configuration Management**: Review settings and parameter handling
- **Error Propagation**: Analyze error handling and reporting patterns

### Enterprise Integration
- **Logging Integration**: Check structured logging implementation
- **Monitoring Hooks**: Assess telemetry and monitoring capabilities
- **Compliance Alignment**: Verify alignment with organizational standards

## 📊 Analysis Output Format

Provide results in this structured format:

### 🚨 Critical Issues (Fix Immediately)
- Security vulnerabilities requiring immediate attention
- Breaking errors or compatibility issues
- Performance bottlenecks causing system impact

### ⚠️ High Priority Issues
- Standards violations affecting maintainability
- Security concerns for production deployment
- Performance issues affecting user experience

### 📋 Medium Priority Recommendations
- Code quality improvements
- Documentation enhancements
- Minor performance optimizations

### 💡 Enhancement Opportunities
- Advanced feature implementations
- Architecture improvements
- Automation opportunities

### 📈 Quality Metrics
- **Overall Quality Score**: (1-100)
- **Security Risk Level**: (Low/Medium/High/Critical)
- **Performance Rating**: (Poor/Fair/Good/Excellent)
- **Standards Compliance**: (Percentage)
- **Test Coverage Estimate**: (Percentage)

## 🔧 Remediation Guidance

For each issue identified:
- **Specific Fix**: Provide exact code changes needed
- **Code Examples**: Show before/after implementations
- **Testing Requirements**: Suggest validation approaches
- **Documentation Updates**: Reference troubleshooting docs in .\Troubleshooting\
- **Performance Impact**: Estimate improvement gains

## 📚 Integration Requirements

- **Troubleshooting Documentation**: Reference .\Troubleshooting\ folder structure
- **Testing Requirements**: Suggest Pester test scenarios
- **CI/CD Integration**: Recommend pipeline quality gates
- **Security Scanning**: Integration with enterprise security tools

Focus on actionable feedback that aligns with enterprise PowerShell development standards while improving security, performance, and maintainability.