---
applyTo: "**/Tests/**/*.ps1,**/*.Tests.ps1"
tools: ['codebase', 'githubRepo']
description: 'Creates comprehensive Pester 6 test suites for PowerShell code with enterprise testing standards'
---

# PowerShell Pester Testing - Core Instructions

Generate enterprise-grade Pester test suites following these core requirements.

**Target version: Pester 6.1+** on Windows PowerShell 5.1 or PowerShell 7.4+. Pester 6 removed
support for PowerShell 3, 4, 6, and unsupported 7.x. 6.1 is additive over 6.0 - no test file needs
to change to move between them.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Quick Reference

### Test Structure Requirements

- **Directory Structure**: Follow [Test Structure Guide](./pester-supporting-docs/test-structure-guide.md)
- **Coverage Target**: Minimum 80% code coverage for production code
- **Test Types**: Unit (mandatory), Integration, Performance, Security
- **Quality Gates**: All tests pass, performance within limits, security validation
- **File Isolation**: Every test file must be self-contained - see below

### Core Test Patterns

Generate tests using these templates:

- **Unit Tests**: Use [Unit Test Template](./pester-supporting-docs/unit-test-template.md)
- **Integration Tests**: Use [Integration Test Template](./pester-supporting-docs/integration-test-template.md)
- **Performance Tests**: Use [Performance Test Template](./pester-supporting-docs/performance-test-template.md)
- **Security Tests**: Use [Security Test Template](./pester-supporting-docs/security-test-template.md)

### Assertions

- **Guide**: Use [Assertion Guide](./pester-supporting-docs/assertion-guide.md)
- **New test files**: prefer the Pester 6 `Should-*` assertions (dash, no space) - they are
  type-aware and produce far better failure messages.
- **Existing files**: keep the file's existing style. Do not mix `Should -Be` and `Should-Be`
  within a single file.
- **Do not** set `Should.DisableV5 = $true` until every test file in the repository is migrated.
- **Custom assertions**: the `Should-*` set is open for extension in 6.1 via `New-ShouldAssertion` -
  see [Custom Assertion Guide](./pester-supporting-docs/custom-assertions.md). Write one only when
  the same domain rule is asserted across several files and naming the offending value is the point.

### Migrating From Pester 5

Follow the [Pester 6 Migration Guide](./pester-supporting-docs/v6-migration.md). The three changes
that break existing suites outright:

1. `Assert-MockCalled` and `Assert-VerifiableMock` were **removed** - use `Should -Invoke` /
   `Should -InvokeVerifiable` (or `Should-Invoke` / `Should-NotInvoke`).
2. Duplicate `BeforeAll`/`BeforeEach`/`AfterAll`/`AfterEach` in the same block now **throw**.
3. `-Focus` and `Set-ItResult -Pending` were **removed**.

### Test Requirements Checklist

- [ ] **File Isolation**: File imports its own modules and does its own discovery-time setup
- [ ] **Parameter Validation**: Test all input validation scenarios
- [ ] **Error Handling**: Verify graceful error handling with meaningful messages
- [ ] **Mocking**: Mock all external dependencies appropriately
- [ ] **Performance**: Include timing and memory usage validation
- [ ] **Security**: Test input sanitization and credential handling
- [ ] **Pipeline Support**: Verify pipeline input/output functionality
- [ ] **Non-Empty Test Cases**: No `-ForEach`/`-TestCases` expression can yield `$null` or `@()`

### Configuration & Execution

- **Configuration**: Use [Pester Configuration Guide](./pester-supporting-docs/pester-configuration.md)
- **Test Execution**: Use [Test Execution Guide](./pester-supporting-docs/test-execution.md)
- **CI/CD Integration**: Follow [CI/CD Integration Guide](./pester-supporting-docs/cicd-integration.md)

### Experimental Options

Three configuration options are experimental, off by default, and may change. Do not enable them in
generated code unless asked; when a project does enable one, these are the consequences:

| Option | Effect | Note |
| --- | --- | --- |
| `Run.Parallel` | One test file per runspace | Requires PowerShell 7+ and file-based containers. Coverage works from 6.1 but is forced onto slower breakpoint mode |
| `Run.Shuffle` | Randomizes file, block, and test order | Fails tests that depend on declaration order. Prints a seed; `Run.ShuffleSeed` replays it. Opt a file out with `#pester:no-shuffle` |
| `Mock.Global` | A mock applies to calls from any module in the runspace | `-ModuleName` becomes a resolution hint, not a scope. Does **not** reinstate fall-through - a `-ParameterFilter` guard still needs a default mock |

All three are per-run configuration, not per-file, apart from the `#pester:no-parallel` and
`#pester:no-shuffle` directives.

### Quality Standards

- **Execution Speed**: Unit tests <30s total, integration tests <5min
- **Test Isolation**: Tests must be independent and repeatable
- **Documentation**: Include troubleshooting references in `./Troubleshooting/` folder
- **Enterprise Standards**: Follow PowerShell community best practices

## Implementation Requirements

When generating Pester tests:

1. **Analyze Function**: Determine test types needed (Unit/Integration/Performance/Security)
2. **Apply Templates**: Use appropriate templates from supporting documentation
3. **Mock Dependencies**: Mock all external calls using the
   [Mocking Patterns Guide](./pester-supporting-docs/mocking-patterns.md)
4. **Validate Coverage**: Ensure 80%+ code coverage with meaningful assertions
5. **Test Data**: Use [Test Data Management Guide](./pester-supporting-docs/test-data-guide.md)
6. **Integration**: Configure for CI/CD pipeline execution

### Every Test File Must Be Self-Contained

Pester 6 discovers and runs **one file at a time**, interleaving discovery and execution, rather
than discovering every file up front. Discovery-time side effects therefore do not carry across
files, and under `Run.Parallel` each file is discovered in its own runspace.

Each test file must import the modules it needs and perform its own discovery-time setup:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }

BeforeDiscovery {
    # Anything needed to BUILD the test tree (-ForEach data, helper commands)
    Import-Module "$PSScriptRoot/../../ModuleName.psd1" -Force
}

BeforeAll {
    # Anything needed to RUN the tests
    Import-Module "$PSScriptRoot/../../ModuleName.psd1" -Force
}
```

When several files share bootstrap, put a `Pester.BeforeContainer.ps1` at the repository root rather
than relying on another file having run first. It is dot-sourced before every container. The
`Run.BeforeContainer` option that also did this was **removed in 6.1**; the convention file is the
only mechanism. It fires only when `Run.RepoRoot` points at the directory holding it - see
[Pester Configuration Guide](./pester-supporting-docs/pester-configuration.md).

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

Only one `BeforeAll`, `BeforeEach`, `AfterAll`, and `AfterEach` per block - duplicates throw in
Pester 6.

### Tagging

Tag every `Describe` block. `None` is a **reserved** filter value in Pester 6 meaning "tests with no
tags" - never use it as a literal tag. Verify tagging coverage with:

```powershell
Invoke-Pester -Path ./Tests -TagFilter 'None'   # a well-tagged suite RUNS zero tests
```

Read the **Passed** count, not the discovered count - `TotalCount` ignores the filter. Scripted
gates must count `$result.Tests | Where-Object ShouldRun`; see
[Test Structure Guide](./pester-supporting-docs/test-structure-guide.md).

### Testing Private Functions

A module built to these standards exports only what `FunctionsToExport` names, so private functions
are unreachable from a test file. Use `InModuleScope` to run assertions inside the module's scope,
where internal functions and classes are visible:

```powershell
It 'Returns a session for the target environment' {
    InModuleScope MyModule {
        $session = Connect-Service -Environment 'Test' -CorrelationId ([guid]::NewGuid())
        $session.Environment | Should-Be 'Test'
    }
}
```

`InModuleScope` is also how you mock a private function that a public one calls, and how you reach a
class defined in `Classes/`:

```powershell
InModuleScope MyModule {
    Mock Get-ServiceStatus { throw 'unreachable' }
    'A', 'B' | Get-Data -ErrorAction SilentlyContinue | Should-BeFalsy
}
```

Do not export a function purely to make it testable - that widens the public contract to serve the
tests. Reach into the module instead.

### Worked Examples

These are complete, passing implementations of the patterns above. Prefer matching them over
inventing a structure:

- [Module-Structure-Example/Tests](../../Documentation/Examples/Module-Structure-Example/Tests/) -
  module contract, class assertions, `InModuleScope` for two private functions, and a per-item
  failure path
- [Testing-Examples/Basic-Function.Tests.ps1](../../Documentation/Examples/Testing-Examples/Basic-Function.Tests.ps1) -
  CIM mocking, `-RemoveParameterType`, `-TestCases`, and mock scoping across contexts
- [Tools/Tests](../../Tools/Tests/) - tests for the repository's own tooling, including fixture
  files written per test and error-path coverage

### Documentation Integration

All test implementations must reference:

- **Troubleshooting**: Link to `./Troubleshooting/` folder documentation
- **Supporting Guides**: Reference detailed templates and patterns
- **Enterprise Standards**: Follow established PowerShell development practices

For detailed implementation guidance, templates, and examples, refer to the supporting documentation
files in the `pester-supporting-docs/` folder.
