---
mode: 'agent'
description: 'PowerShell performance optimization with specific targets'
tools: ['codebase']
---

Analyze and optimize this PowerShell code from ${fileBasename} in the ${workspaceFolderBasename} project:

**Performance Context:**
- **Dataset Size**: ${input:datasetSize:Small (<100 items),Medium (100-1000 items),Large (1000+ items)}
- **Performance Target**: ${input:performanceTarget:Execution time,Memory usage,Throughput,All}
- **Current Environment**: ${input:environment:PowerShell 5.1,PowerShell 7.x,Cross-platform}
- **Criticality**: ${input:criticality:Development,Production,Mission-critical}

**Selected Code:**
```powershell
${selection}
```

**Optimization Analysis:**
1. **Memory Usage**: Resource disposal, StringBuilder usage, collection handling
2. **Pipeline Efficiency**: Pipeline vs. foreach loops for dataset size: ${input:datasetSize}
3. **String Operations**: Concatenation methods and efficiency
4. **Algorithm Complexity**: Performance patterns and scalability
5. **Resource Management**: COM objects, file handles, database connections
6. **Parallel Processing**: PowerShell 7+ ForEach-Object -Parallel opportunities

**Deliverables:**
- Before/after code examples with performance impact estimates
- Memory usage improvements for ${input:datasetSize} datasets
- Scalability recommendations for ${input:criticality} environments
- Benchmarking code for validation
- Reference to .\Troubleshooting\Performance\ documentation

Focus on ${input:performanceTarget} optimization with measurable improvements.

# create-tests.prompt.md
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
