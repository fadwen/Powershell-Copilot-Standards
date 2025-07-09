---
applyTo: "**/Tests/**/*.ps1,**/*.Tests.ps1"
tools: ['codebase', 'githubRepo']
description: 'Creates comprehensive Pester test suites for PowerShell code with enterprise testing standards'
---

# PowerShell Pester Testing - Core Instructions

Generate enterprise-grade Pester test suites following these core requirements:

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain text descriptions and standard ASCII characters only.

## Quick Reference

### Test Structure Requirements
- **Directory Structure**: Follow [Test Structure Guide](./pester-supporting-docs/test-structure-guide.md)
- **Coverage Target**: Minimum 80% code coverage for production code
- **Test Types**: Unit (mandatory), Integration, Performance, Security
- **Quality Gates**: All tests pass, performance within limits, security validation

### Core Test Patterns
Generate tests using these templates:
- **Unit Tests**: Use [Unit Test Template](./pester-supporting-docs/unit-test-template.md)
- **Integration Tests**: Use [Integration Test Template](./pester-supporting-docs/integration-test-template.md)
- **Performance Tests**: Use [Performance Test Template](./pester-supporting-docs/performance-test-template.md)
- **Security Tests**: Use [Security Test Template](./pester-supporting-docs/security-test-template.md)

### Test Requirements Checklist
- [ ] **Parameter Validation**: Test all input validation scenarios
- [ ] **Error Handling**: Verify graceful error handling with meaningful messages
- [ ] **Mocking**: Mock all external dependencies appropriately
- [ ] **Performance**: Include timing and memory usage validation
- [ ] **Security**: Test input sanitization and credential handling
- [ ] **Pipeline Support**: Verify pipeline input/output functionality

### Configuration & Execution
- **Configuration**: Use [Pester Configuration Guide](./pester-supporting-docs/pester-configuration.md)
- **Test Execution**: Use [Test Execution Guide](./pester-supporting-docs/test-execution.md)
- **CI/CD Integration**: Follow [CI/CD Integration Guide](./pester-supporting-docs/cicd-integration.md)

### Quality Standards
- **Execution Speed**: Unit tests <30s total, integration tests <5min
- **Test Isolation**: Tests must be independent and repeatable
- **Documentation**: Include troubleshooting references in `./Troubleshooting/` folder
- **Enterprise Standards**: Follow PowerShell community best practices

## Implementation Requirements

When generating Pester tests:

1. **Analyze Function**: Determine test types needed (Unit/Integration/Performance/Security)
2. **Apply Templates**: Use appropriate templates from supporting documentation
3. **Mock Dependencies**: Mock all external calls using [Mocking Patterns Guide](./pester-supporting-docs/mocking-patterns.md)
4. **Validate Coverage**: Ensure 80%+ code coverage with meaningful assertions
5. **Test Data**: Use [Test Data Management Guide](./pester-supporting-docs/test-data-guide.md)
6. **Integration**: Configure for CI/CD pipeline execution

### Quick Test Generation Pattern
```powershell
# Standard test structure for any function
Describe "Function-Name" -Tag "Unit", "Public" {
    Context "Parameter Validation" { <# Validation tests #> }
    Context "Core Functionality" { <# Main logic tests #> }
    Context "Error Handling" { <# Error scenarios #> }
    Context "Performance Requirements" { <# Performance tests #> }
}
```

### Documentation Integration
All test implementations must reference:
- **Troubleshooting**: Link to `./Troubleshooting/` folder documentation
- **Supporting Guides**: Reference detailed templates and patterns
- **Enterprise Standards**: Follow established PowerShell development practices

For detailed implementation guidance, templates, and examples, refer to the supporting documentation files in the `pester-supporting-docs/` folder.