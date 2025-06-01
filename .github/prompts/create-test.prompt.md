---
mode: 'agent'
description: 'Generate comprehensive tests following modern PowerShell patterns'
tools: ['codebase']
---

Create Pester tests for this PowerShell code:

**Code to Test:**
```powershell
${selection}
```

**Test Configuration:**
- Test type: ${input:testType:Unit,Integration,Performance,Security:Unit}
- Coverage target: ${input:coverage:80%,90%,95%:90%}
- Environment: ${input:environment:Local,CI/CD,Both:Both}
- Pester version: ${input:pesterVersion:5.x,4.x:5.x}

**Test Requirements:**

**1. Modern Test Patterns ✅**
- Use Pester 5.x syntax and features
- Implement proper Arrange-Act-Assert structure
- Include parameterized tests where appropriate
- Use modern mocking techniques

**2. Comprehensive Coverage ✅**
- Happy path scenarios
- Edge cases and boundary conditions
- Error handling verification (using $_ patterns)
- Parameter validation testing

**3. Enterprise Test Standards ✅**
- Correlation ID tracking in tests
- Environment-specific test configurations
- Security validation tests
- Performance assertion tests

**4. Mock Strategy ✅**
- External dependencies isolation
- Credential handling tests (using modern patterns)
- Database/API interaction mocking
- File system operation mocking

**5. Test Organization ✅**
- Clear Describe/Context/It structure
- Meaningful test names and descriptions
- Proper test data management
- Setup and teardown patterns

**Generate tests that:**
- ✅ Validate modern PowerShell patterns (PSCredential::new(), $_ usage)
- ✅ Test error handling appropriately
- ✅ Include security scenario validation
- ✅ Provide clear failure diagnostics
- ✅ Support CI/CD pipeline execution
- ✅ Include performance benchmarks where relevant

Provide complete test file with proper imports and configuration.