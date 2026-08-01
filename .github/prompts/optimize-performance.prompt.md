---
mode: 'agent'
description: 'PowerShell performance optimization with specific targets'
tools: ['codebase']
---

Analyze and optimize this PowerShell code from ${fileBasename} in the ${workspaceFolderBasename} project:

**Performance Context:**

- **Dataset Size**: ${input:datasetSize:Small (<100 items),Medium (100-1000 items),Large (1000+ items)}
- **Performance Target**: ${input:performanceTarget:Execution time,Memory usage,Throughput,All}
- **Current Environment**: ${input:environment:PowerShell 7.6,Windows PowerShell 5.1,Cross-platform}
- **Criticality**: ${input:criticality:Development,Production,Mission-critical}

**Selected Code:**

```powershell
${selection}
```

**Optimization Analysis:**

1. **Memory Usage**: Resource disposal, StringBuilder usage, collection handling
2. **Pipeline Efficiency**: Pipeline vs. foreach loops for dataset size: ${input:datasetSize}
3. **String Operations**: Concatenation methods and efficiency
4. **Algorithm Complexity**: Identify O(n²) operations, inefficient filtering and searching, redundant
   work, and poor data structure choices
5. **Resource Management**: COM objects, file handles, database connections, network call batching
6. **Parallel Processing**: `ForEach-Object -Parallel` opportunities (PowerShell 7.4+; 7.6 is the
   current LTS - 7.0 through 7.3 are retired)

**Deliverables:**

- Before/after code examples with performance impact estimates
- Memory usage improvements for ${input:datasetSize} datasets
- Scalability recommendations for ${input:criticality} environments
- Benchmarking code for validation
- Reference to .\Troubleshooting\Performance\ documentation

Focus on ${input:performanceTarget} optimization with measurable improvements.
