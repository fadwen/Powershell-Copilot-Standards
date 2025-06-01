---
mode: 'agent'
description: 'Detailed performance analysis and benchmarking'
tools: ['codebase']
---

Perform comprehensive performance analysis of PowerShell code in ${fileBasename}:

**Analysis Parameters:**
- **Analysis Scope**: ${input:analysisScope:Single function,Module,Entire script}
- **Performance Metrics**: ${input:metrics:Execution time,Memory usage,CPU utilization,All}
- **Baseline Environment**: ${input:baseline:Development,Production,Benchmarking}
- **Comparison Target**: ${input:target:Current best practice,Industry standard,Previous version}

**Code Under Analysis:**
```powershell
${selection}
```

**Performance Assessment:**
1. **Execution Profiling**
   - Line-by-line execution time analysis
   - Bottleneck identification with specific line numbers
   - Algorithm complexity assessment (O-notation)

2. **Memory Analysis**
   - Memory allocation patterns
   - Garbage collection impact
   - Memory leak detection
   - Object lifecycle management

3. **Resource Utilization**
   - CPU usage patterns
   - I/O operation efficiency
   - Network call optimization
   - Database query performance (if applicable)

4. **Scalability Testing**
   - Performance with dataset sizes: 10, 100, 1000, 10000 items
   - Concurrent execution capabilities
   - Resource exhaustion thresholds

**Deliverables:**
- Performance benchmark results with specific metrics
- Optimization recommendations with priority ranking
- Code examples showing improvements with estimated gains
- Test scripts for ongoing performance monitoring
- Integration with .\Troubleshooting\Performance\ documentation

**Metrics Focus**: Prioritize ${input:metrics} for ${input:baseline} environment against ${input:target} benchmarks.

Generate actionable performance optimization plan for ${workspaceFolderBasename} project.