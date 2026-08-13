# Performance Test Template

Targets **Pester 6.1+**. Uses the `Should-*` assertion syntax - see
[Assertion Guide](./assertion-guide.md).

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Standard Performance Test Structure

Use this template for performance benchmarking and regression detection:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }

# Performance measurement is meaningless when other test files are competing for the
# CPU. This directive keeps the file on the serial path even when Run.Parallel is set.
#pester:no-parallel

BeforeAll {
    # Import module under test. Each file is self-contained in Pester 6.
    $ModulePath = Join-Path $PSScriptRoot '..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force

    # Performance test configuration
    $PerformanceConfig = @{
        BaselineDataSize = 100
        ScaleTestDataSize = 1000
        MaxExecutionTime = [TimeSpan]::FromSeconds(30)
        MaxMemoryUsageMB = 100
        WarmupIterations = 3
        TestIterations = 5
    }

    # Load performance baselines
    $BaselinePath = Join-Path $PSScriptRoot "..\TestData\performance-baselines.psd1"
    if (Test-Path $BaselinePath) {
        $PerformanceBaselines = Import-PowerShellDataFile $BaselinePath
    } else {
        $PerformanceBaselines = @{}
    }
}

Describe "Performance Tests" -Tag "Performance", "Benchmark" {
    Context "Execution Time Baselines" {
        BeforeEach {
            # Warm up the function
            1..$PerformanceConfig.WarmupIterations | ForEach-Object {
                Function-Name -ParameterName 'WarmupValue' | Out-Null
            }

            # Force garbage collection for consistent baseline
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }

        It "Should process a single item faster than the baseline" {
            # Should-BeFasterThan takes the scriptblock and a duration string or TimeSpan,
            # and reports the measured time in the failure message.
            { Function-Name -ParameterName 'SingleItem' } | Should-BeFasterThan '1s'
        }

        It "Should process single item within baseline across iterations" {
            $baseline = if ($PerformanceBaselines.SingleItemBaseline) {
                $PerformanceBaselines.SingleItemBaseline
            } else {
                [TimeSpan]::FromSeconds(1)
            }
            $measurements = @()

            # Run multiple iterations for accurate measurement
            1..$PerformanceConfig.TestIterations | ForEach-Object {
                $executionTime = Measure-Command {
                    Function-Name -ParameterName 'SingleItem'
                }
                $measurements += $executionTime.TotalMilliseconds
            }

            $averageMs = ($measurements | Measure-Object -Average).Average
            $maxMs     = ($measurements | Measure-Object -Maximum).Maximum

            # Compare like with like - milliseconds against milliseconds. Comparing a
            # TimeSpan against a raw number silently coerces and gives nonsense results.
            $averageMs | Should-BeLessThan $baseline.TotalMilliseconds
            $maxMs     | Should-BeLessThan ($baseline.TotalMilliseconds * 1.5) `
                -Because 'peak may exceed the average baseline by up to 50%'
        }

        It "Should scale efficiently with data volume" {
            $baselineItems = 1..$PerformanceConfig.BaselineDataSize
            $scaledItems = 1..$PerformanceConfig.ScaleTestDataSize

            # Measure baseline performance
            $baselineTime = Measure-Command {
                Function-Name -ParameterName $baselineItems
            }

            # Measure scaled performance
            $scaledTime = Measure-Command {
                Function-Name -ParameterName $scaledItems
            }

            # Calculate scaling efficiency
            $dataScaleFactor = $PerformanceConfig.ScaleTestDataSize / $PerformanceConfig.BaselineDataSize
            $timeScaleFactor = $scaledTime.TotalMilliseconds / $baselineTime.TotalMilliseconds

            # Should scale sub-linearly due to optimizations
            $scalingEfficiency = $timeScaleFactor / $dataScaleFactor
            $scalingEfficiency | Should-BeLessThan 1.5 -Because 'processing should scale sub-linearly'
        }

        It "Should complete large datasets within time limit" {
            $largeDataset = 1..5000
            $result = $null

            # Do not put assertions inside Measure-Command - the assertion cost lands in
            # the measurement, and a failure there reports a confusing location.
            $executionTime = Measure-Command {
                $result = Function-Name -ParameterName $largeDataset
            }

            $result | Should-BeCollection -Count 5000
            $executionTime.TotalMilliseconds |
                Should-BeLessThan $PerformanceConfig.MaxExecutionTime.TotalMilliseconds
        }

        It "Should maintain consistent performance across iterations" {
            $iterations = 10
            $measurements = @()

            1..$iterations | ForEach-Object {
                $time = Measure-Command {
                    Function-Name -ParameterName (1..100)
                }
                $measurements += $time.TotalMilliseconds
            }

            # Calculate coefficient of variation (CV)
            $average = ($measurements | Measure-Object -Average).Average
            $stdDev = [Math]::Sqrt((($measurements | ForEach-Object { ($_ - $average) * ($_ - $average) }) | Measure-Object -Sum).Sum / $iterations)
            $cv = $stdDev / $average

            # CV should be less than 20% for consistent performance
            $cv | Should-BeLessThan 0.20 -Because 'execution time should be stable across runs'
        }
    }

    Context "Memory Usage" {
        It "Should maintain reasonable memory footprint" {
            $beforeMemory = [System.GC]::GetTotalMemory($true)

            Function-Name -ParameterName (1..$PerformanceConfig.ScaleTestDataSize)

            $afterMemory = [System.GC]::GetTotalMemory($false)  # Don't force GC yet
            $memoryUsedMB = ($afterMemory - $beforeMemory) / 1MB

            $memoryUsedMB | Should-BeLessThan $PerformanceConfig.MaxMemoryUsageMB
        }

        It "Should release memory after completion" {
            $beforeMemory = [System.GC]::GetTotalMemory($true)

            Function-Name -ParameterName (1..$PerformanceConfig.ScaleTestDataSize)

            # Force garbage collection
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            [System.GC]::Collect()

            $afterMemory = [System.GC]::GetTotalMemory($true)
            $memoryDifference = [Math]::Abs($afterMemory - $beforeMemory) / 1MB

            # Should release most memory (allow 10MB tolerance)
            $memoryDifference | Should-BeLessThan 10 -Because 'the function should not retain allocations'
        }

        It "Should not have memory leaks with repeated calls" {
            $initialMemory = [System.GC]::GetTotalMemory($true)
            $memoryMeasurements = @()

            # Execute function multiple times
            1..20 | ForEach-Object {
                Function-Name -ParameterName (1..100)

                # Measure memory every 5 iterations
                if ($_ % 5 -eq 0) {
                    [System.GC]::Collect()
                    $currentMemory = [System.GC]::GetTotalMemory($true)
                    $memoryMeasurements += ($currentMemory - $initialMemory) / 1MB
                }
            }

            # Memory usage should not continuously increase
            $firstMeasurement = $memoryMeasurements[0]
            $lastMeasurement = $memoryMeasurements[-1]
            $memoryGrowth = $lastMeasurement - $firstMeasurement

            # Allow maximum 5MB growth over 20 iterations
            $memoryGrowth | Should-BeLessThan 5 -Because 'repeated calls must not leak'
        }
    }

    Context "Throughput and Scalability" {
        It "Should achieve minimum throughput requirements" {
            $testData = 1..1000
            $requiredThroughput = 50  # items per second
            $results = $null

            $executionTime = Measure-Command {
                $results = Function-Name -ParameterName $testData
            }

            $results | Should-BeCollection -Count 1000

            $actualThroughput = 1000 / $executionTime.TotalSeconds
            $actualThroughput | Should-BeGreaterThan $requiredThroughput
        }

        It "Should handle concurrent execution efficiently" {
            $concurrentJobs = 1..5 | ForEach-Object {
                Start-Job -ScriptBlock {
                    param($ModulePath, $JobId)

                    Import-Module $ModulePath -Force

                    $startTime = Get-Date
                    $result = Function-Name -ParameterName (1..200)
                    $endTime = Get-Date

                    return @{
                        JobId = $JobId
                        ItemsProcessed = $result.Count
                        ExecutionTime = ($endTime - $startTime).TotalMilliseconds
                        Success = $result.Count -eq 200
                    }
                } -ArgumentList $ModulePath, $_
            }

            # Wait for all jobs to complete
            $results = $concurrentJobs | Wait-Job | Receive-Job
            $concurrentJobs | Remove-Job

            # Verify all jobs completed successfully
            $results | Should-All { $_.Success }
            $results | Should-All { $_.ItemsProcessed -eq 200 }
            $results | Should-All { $_.ExecutionTime -lt 30000 }   # 30 seconds max

            # Verify concurrent execution didn't significantly degrade performance
            $averageConcurrentTime = ($results.ExecutionTime | Measure-Object -Average).Average
            $serialTime = Measure-Command { Function-Name -ParameterName (1..200) }

            # Concurrent execution should not be more than 2x slower per job
            $averageConcurrentTime | Should-BeLessThan ($serialTime.TotalMilliseconds * 2)
        }
    }

    Context "Resource Utilization" {
        It "Should efficiently use CPU resources" {
            $cpuCounter = Get-Counter "\Process(powershell*)\% Processor Time" -ErrorAction SilentlyContinue

            if ($cpuCounter) {
                $beforeCpu = $cpuCounter.CounterSamples | Where-Object { $_.InstanceName -like "*$PID*" } | Select-Object -First 1 -ExpandProperty CookedValue

                Function-Name -ParameterName (1..1000)

                Start-Sleep -Seconds 1  # Allow CPU counter to update
                $afterCpu = (Get-Counter "\Process(powershell*)\% Processor Time").CounterSamples | Where-Object { $_.InstanceName -like "*$PID*" } | Select-Object -First 1 -ExpandProperty CookedValue

                # CPU usage should be reasonable (less than 80% for single-threaded operation)
                $cpuUsage = $afterCpu - $beforeCpu
                $cpuUsage | Should-BeLessThan 80
            } else {
                Set-ItResult -Skipped -Because "CPU performance counters not available"
            }
        }

        It "Should not create excessive temporary files" {
            $tempFilesBefore = @(Get-ChildItem -Path $env:TEMP -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) })

            Function-Name -ParameterName (1..500)

            $tempFilesAfter = @(Get-ChildItem -Path $env:TEMP -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) })

            $newTempFiles = $tempFilesAfter.Count - $tempFilesBefore.Count

            # Should not create more than 5 temporary files
            $newTempFiles | Should-BeLessThanOrEqual 5
        }
    }
}

AfterAll {
    # Save performance metrics for baseline comparison
    $resultsPath = Join-Path $PSScriptRoot "..\Results\performance-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"

    $performanceMetrics = @{
        TestDate = Get-Date
        PowerShellVersion = $PSVersionTable.PSVersion
        Platform = $PSVersionTable.Platform
        # Add specific metrics from test execution
    }

    $performanceMetrics | ConvertTo-Json -Depth 10 | Out-File $resultsPath
}
```

## Pester 6 Notes for Performance Tests

### Always opt out of parallel execution

Put `#pester:no-parallel` at the top of every performance test file. Timing measurements taken while
other test files compete for CPU are noise. Opted-out files run serially in the parent session while
other files run in parallel, so you keep the speedup elsewhere without corrupting the benchmarks.

Belt and braces: also keep `Run.Parallel = $false` in `PesterConfiguration.Performance.psd1`.

### Use `Should-BeFasterThan` for simple time limits

```powershell
{ Function-Name -ParameterName 'x' } | Should-BeFasterThan '250ms'
{ Function-Name -ParameterName 'x' } | Should-BeSlowerThan '10ms'
```

It accepts a duration string (`'250ms'`, `'2s'`) or a `TimeSpan`, measures the scriptblock, and puts
the actual measured time in the failure message. Prefer it over `Measure-Command` plus a comparison
for single-shot limits. Keep `Measure-Command` where you need the measurement itself for ratios,
averages, or coefficient-of-variation math.

### Compare like with like

The most common bug in hand-rolled performance assertions is comparing a `TimeSpan` against a raw
number:

```powershell
# WRONG - TimeSpan vs. double; the comparison does not mean what it looks like
$elapsed | Should-BeLessThan ($baseline.TotalMilliseconds * 1.5)

# RIGHT - both sides in milliseconds
$elapsed.TotalMilliseconds | Should-BeLessThan ($baseline.TotalMilliseconds * 1.5)

# ALSO RIGHT - both sides TimeSpan
$elapsed | Should-BeLessThan ([TimeSpan]::FromMilliseconds($baseline.TotalMilliseconds * 1.5))
```

Pester 6's type-aware assertions make the mismatch visible in the failure message, but the fix is to
not write it in the first place.

### Keep assertions out of `Measure-Command`

An assertion inside the measured scriptblock adds its own cost to the measurement, and a failure
there reports a confusing location. Capture the result, measure, then assert.

### Never enable coverage on a performance job

Coverage instruments exactly the thing you are measuring, so the numbers stop meaning anything.

Pester 6.0 refused to combine coverage with `Run.Parallel` at all, falling back to sequential with a
warning. 6.1 does collect coverage across parallel workers - but it forces breakpoint-based
collection to do it, which is heavier per file than the default profiler tracer. Either way, a
performance job should run sequentially with coverage off.

## Performance Test Guidelines

### Baseline Establishment

- Warm up functions before measurement
- Run multiple iterations for accuracy
- Force garbage collection for consistency
- Establish realistic performance targets

### Memory Testing

- Measure memory usage during execution
- Verify memory release after completion
- Test for memory leaks with repeated calls
- Monitor garbage collection patterns

### Scalability Testing

- Test with increasing data sizes
- Measure throughput and response time
- Validate concurrent execution performance
- Test resource utilization limits

### Regression Detection

- Compare against historical baselines
- Track performance trends over time
- Alert on significant performance degradation
- Maintain performance metrics database

### Resource Monitoring

- Monitor CPU utilization
- Track temporary file creation
- Measure network usage (if applicable)
- Validate resource cleanup
