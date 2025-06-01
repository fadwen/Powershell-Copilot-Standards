---
mode: 'agent'
description: 'Generate comprehensive Pester tests with coverage targets'
tools: ['codebase']
---

Create Pester test suite for PowerShell code in ${fileBasename} from ${workspaceFolderBasename} project:

**Test Configuration:**
- **Function Name**: ${input:functionName:Extract from selected code}
- **Test Types**: ${input:testTypes:Unit,Integration,Performance,Security,All}
- **Coverage Target**: ${input:coverageTarget:80%,90%,95%}
- **Pester Version**: ${input:pesterVersion:5.x}
- **Test Environment**: ${input:testEnvironment:Local,CI/CD,Both}

**Selected Function:**
```powershell
${selection}
```

**Test Suite Requirements:**
1. **Parameter Validation Tests**
   - Valid input scenarios with test cases
   - Invalid input rejection with expected errors
   - Boundary condition testing

2. **Functionality Tests**
   - Success scenarios with mocked dependencies
   - Expected output validation
   - Pipeline input/output testing

3. **Error Handling Tests**
   - Exception handling validation
   - Graceful failure scenarios
   - Correlation ID tracking verification

4. **Performance Tests** (if ${input:testTypes} includes Performance)
   - Execution time benchmarks
   - Memory usage validation
   - Scalability testing

5. **Security Tests** (if ${input:testTypes} includes Security)
   - Input sanitization validation
   - Credential handling verification
   - Security logging tests

**Enterprise Standards:**
- Achieve ${input:coverageTarget} code coverage minimum
- Include BeforeAll/AfterAll setup and cleanup
- Use proper mocking for external dependencies
- Follow AAA pattern (Arrange, Act, Assert)
- Include descriptive test names and documentation

Generate complete Pester test file targeting ${input:coverageTarget} coverage for ${input:testEnvironment} execution.
