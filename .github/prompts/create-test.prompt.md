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
- Pester version: ${input:pesterVersion:6.1+,5.x:6.1+}

**Test Requirements:**

**1. Modern Test Patterns ✅**

- Use Pester 6.1+ syntax and features. Pester 6 requires Windows PowerShell 5.1 or PowerShell 7.4+;
  target 7.6 (LTS) for new work, as 7.4 and 7.5 reach end of support on 10-Nov-2026
- Prefer the `Should-*` assertions (dash, no space) for new test files; classic
  `Should -Be` remains supported for existing suites
- Make every test file self-contained: Pester 6 discovers and runs one file at a time,
  so each file imports its own modules and does its own `BeforeDiscovery` setup
- Build `-ForEach` / `-TestCases` data in `BeforeDiscovery`, never `BeforeAll`
- Do not use `Assert-MockCalled`, `Assert-VerifiableMock`, `-Focus`, or
  `Set-ItResult -Pending` - all removed in Pester 6
- Implement proper Arrange-Act-Assert structure
- Include parameterized tests where appropriate
- Use modern mocking techniques (`Should-Invoke` / `Should-NotInvoke`)

**2. Comprehensive Coverage ✅**

- Happy path scenarios
- Edge cases and boundary conditions
- Error handling verification (using $_ patterns)
- Parameter validation testing
- Pipeline input and output behaviour (ValueFromPipeline binding, per-item emission)

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
