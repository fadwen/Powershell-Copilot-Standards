# Pester Configuration Guide

## Standard Pester Configuration

Use this standardized configuration for consistent test execution:

```powershell
# PesterConfiguration.psd1
@{
    Run = @{
        Path = @('./Tests/Unit', './Tests/Integration')
        PassThru = $true
        Throw = $true
        SkipRun = $false
    }

    Output = @{
        Verbosity = 'Detailed'
        StackTraceVerbosity = 'Filtered'
        CIFormat = 'Auto'
    }

    CodeCoverage = @{
        Enabled = $true
        Path = @('./Public/*.ps1', './Private/*.ps1', './Classes/*.ps1')
        OutputFormat = 'JaCoCo'
        OutputPath = './Tests/Results/Coverage.xml'
        Threshold = 80
        UseBreakpoints = $false
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './Tests/Results/TestResults.xml'
        TestSuiteName = 'PowerShell Tests'
    }

    Should = @{
        ErrorAction = 'Stop'
    }

    Debug = @{
        ShowFullErrors = $false
        WriteDebugMessages = $false
        WriteDebugMessagesFrom = @()
        ReturnRawResultObject = $false
    }

    Filter = @{
        Tag = @()
        ExcludeTag = @()
        Line = @()
        ExcludeLine = @()
        FullName = @()
    }
}
```

## Environment-Specific Configurations

### Development Configuration
```powershell
# PesterConfiguration.Development.psd1
@{
    Run = @{
        Path = @('./Tests/Unit')
        PassThru = $true
    }

    Output = @{
        Verbosity = 'Detailed'
    }

    CodeCoverage = @{
        Enabled = $true
        Threshold = 70  # Lower threshold for development
    }
}
```

### CI/CD Configuration
```powershell
# PesterConfiguration.CI.psd1
@{
    Run = @{
        Path = @('./Tests/Unit', './Tests/Integration', './Tests/Security')
        PassThru = $true
        Throw = $true
        Exit = $true
    }

    Output = @{
        Verbosity = 'Normal'
        CIFormat = 'GithubActions'  # or 'AzureDevops'
    }

    CodeCoverage = @{
        Enabled = $true
        Threshold = 80
        OutputFormat = 'JaCoCo'
        OutputPath = './Tests/Results/Coverage.xml'
    }

    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './Tests/Results/TestResults.xml'
    }
}
```

### Performance Testing Configuration
```powershell
# PesterConfiguration.Performance.psd1
@{
    Run = @{
        Path = @('./Tests/Performance')
        PassThru = $true
    }

    Output = @{
        Verbosity = 'Minimal'
    }

    Filter = @{
        Tag = @('Performance', 'Benchmark')
    }

    TestResult = @{
        Enabled = $true
        OutputPath = './Tests/Results/PerformanceResults.xml'
    }
}
```

## Dynamic Configuration Loading

### Configuration Loader Function
```powershell
function Get-PesterConfiguration {
    [CmdletBinding()]
    param(
        [ValidateSet('Development', 'CI', 'Performance', 'Security', 'Integration')]
        [string]$Environment = 'Development',
        [string]$ConfigPath = './Tests'
    )

    # Load base configuration
    $baseConfigPath = Join-Path $ConfigPath "PesterConfiguration.psd1"
    $baseConfig = Import-PowerShellDataFile $baseConfigPath

    # Load environment-specific overrides
    $envConfigPath = Join-Path $ConfigPath "PesterConfiguration.$Environment.psd1"
    if (Test-Path $envConfigPath) {
        $envConfig = Import-PowerShellDataFile $envConfigPath

        # Merge configurations (environment overrides base)
        $mergedConfig = Merge-HashTable $baseConfig $envConfig
    } else {
        $mergedConfig = $baseConfig
    }

    # Create Pester configuration object
    return New-PesterConfiguration -Hashtable $mergedConfig
}

function Merge-HashTable {
    param(
        [hashtable]$Base,
        [hashtable]$Override
    )

    $result = $Base.Clone()

    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-HashTable $result[$key] $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }

    return $result
}
```

## Test Filtering Configuration

### Tag-Based Filtering
```powershell
# Filter by test type
$config.Filter.Tag = @('Unit')           # Only unit tests
$config.Filter.Tag = @('Integration')    # Only integration tests
$config.Filter.Tag = @('Security')       # Only security tests

# Filter by priority
$config.Filter.Tag = @('Critical')       # Only critical tests
$config.Filter.ExcludeTag = @('Slow')    # Exclude slow tests

# Combined filtering
$config.Filter.Tag = @('Unit', 'Public') # Unit tests for public functions only
```

### Path-Based Filtering
```powershell
# Test specific modules
$config.Run.Path = @('./Tests/Unit/Public/Get-*.Tests.ps1')

# Test specific areas
$config.Run.Path = @('./Tests/Unit/Authentication', './Tests/Unit/Authorization')
```

## Code Coverage Configuration

### Coverage Paths
```powershell
$config.CodeCoverage.Path = @(
    './Public/*.ps1',           # All public functions
    './Private/*.ps1',          # All private functions
    './Classes/*.ps1',          # All class files
    './Modules/*/Public/*.ps1'  # Multi-module support
)
```

### Coverage Exclusions
```powershell
# Exclude specific files or patterns
$config.CodeCoverage.ExcludePath = @(
    './Private/Legacy*.ps1',    # Exclude legacy code
    './Tests/**/*.ps1',         # Exclude test files
    './Build/**/*.ps1'          # Exclude build scripts
)
```

### Coverage Thresholds
```powershell
# Global threshold
$config.CodeCoverage.Threshold = 80

# Per-file thresholds (if supported)
$config.CodeCoverage.PerFileThreshold = 70
```

## Output Configuration

### Verbosity Levels
```powershell
# Minimal - Only summary
$config.Output.Verbosity = 'Minimal'

# Normal - Standard output
$config.Output.Verbosity = 'Normal'

# Detailed - Verbose output with test details
$config.Output.Verbosity = 'Detailed'

# Diagnostic - Full diagnostic information
$config.Output.Verbosity = 'Diagnostic'
```

### CI/CD Integration
```powershell
# GitHub Actions
$config.Output.CIFormat = 'GithubActions'

# Azure DevOps
$config.Output.CIFormat = 'AzureDevops'

# Auto-detect
$config.Output.CIFormat = 'Auto'
```

## Test Result Configuration

### Output Formats
```powershell
# NUnit XML (most common)
$config.TestResult.OutputFormat = 'NUnitXml'

# JUnit XML
$config.TestResult.OutputFormat = 'JUnitXml'

# VSTest format
$config.TestResult.OutputFormat = 'VSTest'
```

### Custom Result Processing
```powershell
# Custom test result handler
$config.TestResult.OutputPath = './Tests/Results/CustomResults.xml'
$config.TestResult.TestSuiteName = 'Custom Test Suite'

# Multiple output formats
$config.TestResult = @(
    @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './Tests/Results/NUnit.xml'
    },
    @{
        Enabled = $true
        OutputFormat = 'JUnitXml'
        OutputPath = './Tests/Results/JUnit.xml'
    }
)
```

## Configuration Best Practices

### Environment Detection
```powershell
# Auto-detect CI/CD environment
if ($env:CI -eq 'true' -or $env:BUILD_ID) {
    $environment = 'CI'
} elseif ($env:PERFORMANCE_TESTING -eq 'true') {
    $environment = 'Performance'
} else {
    $environment = 'Development'
}

$config = Get-PesterConfiguration -Environment $environment
```

### Configuration Validation
```powershell
function Test-PesterConfiguration {
    param([object]$Configuration)

    # Validate required paths exist
    foreach ($path in $Configuration.Run.Path) {
        if (-not (Test-Path $path)) {
            Write-Warning "Test path not found: $path"
        }
    }

    # Validate output directories
    $outputDir = Split-Path $Configuration.TestResult.OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force
    }

    # Validate coverage thresholds
    if ($Configuration.CodeCoverage.Threshold -gt 100 -or $Configuration.CodeCoverage.Threshold -lt 0) {
        throw "Invalid coverage threshold: $($Configuration.CodeCoverage.Threshold)"
    }
}
```

### Configuration Inheritance
```powershell
# Base configuration for organization
$orgConfig = @{
    CodeCoverage = @{
        Threshold = 80
        OutputFormat = 'JaCoCo'
    }
    TestResult = @{
        OutputFormat = 'NUnitXml'
    }
}

# Project-specific overrides
$projectConfig = @{
    CodeCoverage = @{
        Threshold = 85  # Higher threshold for critical project
    }
}

# Merge configurations
$finalConfig = Merge-HashTable $orgConfig $projectConfig
```
