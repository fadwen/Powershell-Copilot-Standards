# Test Data Management Guide

Targets **Pester 6.1+**.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Discovery-Time vs. Run-Time Data

This is the most important distinction in Pester 6 test data, and getting it wrong fails silently.

| Data drives... | Must be built in | Why |
| --- | --- | --- |
| `-ForEach` / `-TestCases` (the test _tree_) | `BeforeDiscovery` | Discovery runs before `BeforeAll` |
| Assertions inside `It` (the test _body_) | `BeforeAll` / `BeforeEach` | Runs at execution time |

```powershell
BeforeDiscovery {
    # Shapes the test tree - one It per user
    $TestUsers = New-TestUsers -Count 3 -Type 'Standard'
}

BeforeAll {
    # Used inside test bodies
    $TestConfig = New-TestConfiguration -Environment 'Testing'
}

Describe 'User processing' {
    It 'processes <Name>' -ForEach $TestUsers.ForEach({ @{ Name = $_.FullName; User = $_ } }) {
        Process-User -User $User -Config $TestConfig | Should-BeTrue
    }
}
```

Building `-ForEach` data in `BeforeAll` leaves it `$null` during discovery. Piping `$null` through
`ForEach-Object` yields **one** iteration, so the suite collapses to a single bogus test and reports
green. If the source is an empty array instead, Pester 6 fails discovery outright
(`Run.FailOnNullOrEmptyForEach`).

Because Pester 6 discovers **one file at a time**, discovery-time data must also be produced by the
file that uses it - a helper module imported by another test file is not guaranteed to be loaded.
Import helpers in the same file, or provide them via a `Pester.BeforeContainer.ps1` at the
repository root.

### Test data must be deterministic at discovery time

`TestDataFactory` below uses `Get-Random`. That is fine for run-time data, but data feeding
`-ForEach` should be **stable** - under `Run.Parallel` each file is discovered in its own runspace,
and randomized test _names_ make failures hard to correlate across runs and reports.

For discovery-time data, prefer fixed fixtures or a seeded generator:

```powershell
BeforeDiscovery {
    # Stable names - the same test identity on every run and in every runspace
    $TestCases = Import-PowerShellDataFile "$PSScriptRoot/../TestData/user-cases.psd1"
}
```

Keep `Get-Random` for values consumed inside `It` bodies, where the name is already fixed.

## Test Data Organization

### Test Data Directory Structure

```text
Tests/
├── TestData/
│   ├── Configurations/
│   │   ├── development.psd1
│   │   ├── testing.psd1
│   │   └── production.psd1
│   ├── SampleData/
│   │   ├── users.json
│   │   ├── servers.csv
│   │   └── configurations.xml
│   ├── MockResponses/
│   │   ├── api-responses.json
│   │   ├── database-results.json
│   │   └── service-responses.json
│   ├── Templates/
│   │   ├── user-template.json
│   │   ├── server-template.json
│   │   └── config-template.psd1
│   ├── Baselines/
│   │   ├── performance-baselines.psd1
│   │   └── security-baselines.json
│   └── Fixtures/
│       ├── test-certificates/
│       ├── test-files/
│       └── sample-logs/
├── TestHelpers/
│   ├── TestDataFactory.ps1
│   ├── MockDataGenerator.ps1
│   └── DataValidation.ps1
```

## Test Data Factory

### Comprehensive Test Data Factory

```powershell
# TestHelpers/TestDataFactory.ps1

class TestDataFactory {
    static [hashtable] $Cache = @{}
    static [string] $DataPath = (Join-Path $PSScriptRoot '..\TestData')

    # User data generation
    static [object[]] CreateUsers([int]$Count = 5, [string]$Type = 'Standard') {
        $cacheKey = "Users_$($Count)_$Type"

        if ([TestDataFactory]::Cache.ContainsKey($cacheKey)) {
            return [TestDataFactory]::Cache[$cacheKey]
        }

        $users = switch ($Type) {
            'Standard' { [TestDataFactory]::CreateStandardUsers($Count) }
            'Admin' { [TestDataFactory]::CreateAdminUsers($Count) }
            'Disabled' { [TestDataFactory]::CreateDisabledUsers($Count) }
            'Mixed' { [TestDataFactory]::CreateMixedUsers($Count) }
            default { [TestDataFactory]::CreateStandardUsers($Count) }
        }

        [TestDataFactory]::Cache[$cacheKey] = $users
        return $users
    }

    static [object[]] CreateStandardUsers([int]$Count) {
        $departments = @('IT', 'HR', 'Finance', 'Marketing', 'Operations')
        $titles = @('Analyst', 'Specialist', 'Coordinator', 'Manager', 'Director')

        return 1..$Count | ForEach-Object {
            $firstName = [TestDataFactory]::GetRandomFirstName()
            $lastName = [TestDataFactory]::GetRandomLastName()

            @{
                Id = $_
                FirstName = $firstName
                LastName = $lastName
                FullName = "$firstName $lastName"
                Email = "$($firstName.ToLower()).$($lastName.ToLower())@company.com"
                Department = Get-Random -InputObject $departments
                Title = Get-Random -InputObject $titles
                Active = $true
                CreatedDate = (Get-Date).AddDays(-((Get-Random -Minimum 1 -Maximum 365)))
                LastLoginDate = (Get-Date).AddDays(-((Get-Random -Minimum 1 -Maximum 30)))
            }
        }
    }

    static [object[]] CreateAdminUsers([int]$Count) {
        $adminTitles = @('System Administrator', 'Database Administrator', 'Network Administrator', 'Security Administrator')

        return 1..$Count | ForEach-Object {
            $firstName = [TestDataFactory]::GetRandomFirstName()
            $lastName = [TestDataFactory]::GetRandomLastName()

            @{
                Id = $_ + 1000
                FirstName = $firstName
                LastName = $lastName
                FullName = "$firstName $lastName"
                Email = "$($firstName.ToLower()).$($lastName.ToLower())@company.com"
                Department = 'IT'
                Title = Get-Random -InputObject $adminTitles
                Active = $true
                IsAdmin = $true
                Privileges = @('UserManagement', 'SystemConfiguration', 'SecurityManagement')
                CreatedDate = (Get-Date).AddDays(-((Get-Random -Minimum 30 -Maximum 365)))
                LastLoginDate = (Get-Date).AddDays(-((Get-Random -Minimum 1 -Maximum 7)))
            }
        }
    }

    # Server data generation
    static [object[]] CreateServers([int]$Count = 10, [string]$Environment = 'Mixed') {
        $cacheKey = "Servers_$($Count)_$Environment"

        if ([TestDataFactory]::Cache.ContainsKey($cacheKey)) {
            return [TestDataFactory]::Cache[$cacheKey]
        }

        $environments = switch ($Environment) {
            'Production' { @('Production') }
            'Development' { @('Development') }
            'Testing' { @('Testing') }
            'Mixed' { @('Production', 'Development', 'Testing', 'Staging') }
            default { @('Production', 'Development', 'Testing') }
        }

        $roles = @('Web Server', 'Database Server', 'Application Server', 'Domain Controller', 'File Server')
        $operatingSystems = @('Windows Server 2019', 'Windows Server 2022', 'Ubuntu 20.04 LTS', 'CentOS 8')

        $servers = 1..$Count | ForEach-Object {
            $environment = Get-Random -InputObject $environments
            $role = Get-Random -InputObject $roles

            @{
                Id = $_
                Name = "SRV$($environment.Substring(0,1).ToUpper())$($_.ToString('00'))"
                FQDN = "srv$($environment.ToLower())$($_.ToString('00')).company.local"
                IPAddress = "192.168.$((Get-Random -Minimum 1 -Maximum 254)).$((Get-Random -Minimum 1 -Maximum 254))"
                Environment = $environment
                Role = $role
                OperatingSystem = Get-Random -InputObject $operatingSystems
                CPU = Get-Random -InputObject @(2, 4, 8, 16)
                Memory = Get-Random -InputObject @(8, 16, 32, 64, 128)
                DiskSpace = Get-Random -InputObject @(100, 250, 500, 1000, 2000)
                Status = Get-Random -InputObject @('Running', 'Running', 'Running', 'Stopped', 'Maintenance')  # Weighted toward Running
                LastUpdated = (Get-Date).AddDays(-((Get-Random -Minimum 1 -Maximum 30)))
                MonitoringEnabled = $true
            }
        }

        [TestDataFactory]::Cache[$cacheKey] = $servers
        return $servers
    }

    # Configuration data generation
    static [hashtable] CreateConfiguration([string]$Environment = 'Testing', [string]$Application = 'Default') {
        return @{
            Environment = $Environment
            Application = $Application
            Database = @{
                ConnectionString = "Server=db-$($Environment.ToLower()).company.local;Database=$Application;Integrated Security=true"
                CommandTimeout = 30
                ConnectionPoolSize = 100
            }
            Logging = @{
                Level = if ($Environment -eq 'Production') { 'Information' } else { 'Debug' }
                Path = "C:\Logs\$Application"
                RetentionDays = if ($Environment -eq 'Production') { 90 } else { 30 }
                MaxFileSize = '10MB'
            }
            Security = @{
                RequireSSL = $Environment -eq 'Production'
                SessionTimeout = 1800
                MaxLoginAttempts = 3
                PasswordPolicy = @{
                    MinLength = 8
                    RequireUppercase = $true
                    RequireNumbers = $true
                    RequireSpecialChars = $Environment -eq 'Production'
                }
            }
            Performance = @{
                CacheEnabled = $true
                CacheTimeout = 3600
                MaxConcurrentUsers = if ($Environment -eq 'Production') { 1000 } else { 100 }
                RequestTimeout = 60000
            }
            Features = @{
                FeatureA = $true
                FeatureB = $Environment -ne 'Production'  # Beta features disabled in prod
                FeatureC = $false
                Maintenance = $Environment -eq 'Development'
            }
        }
    }

    # API Response data generation
    static [hashtable] CreateAPIResponse([string]$Type = 'Success', [object]$Data = $null) {
        $baseResponse = @{
            Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffZ'
            RequestId = [System.Guid]::NewGuid().ToString()
            Version = '1.0.0'
        }

        switch ($Type) {
            'Success' {
                $baseResponse.Success = $true
                $baseResponse.StatusCode = 200
                $baseResponse.Message = 'Request completed successfully'
                $baseResponse.Data = $Data ?? @{ Result = 'Success' }
            }
            'Error' {
                $baseResponse.Success = $false
                $baseResponse.StatusCode = 500
                $baseResponse.Message = 'Internal server error occurred'
                $baseResponse.Error = @{
                    Code = 'INTERNAL_ERROR'
                    Details = 'An unexpected error occurred while processing the request'
                    Timestamp = $baseResponse.Timestamp
                }
            }
            'NotFound' {
                $baseResponse.Success = $false
                $baseResponse.StatusCode = 404
                $baseResponse.Message = 'Requested resource not found'
                $baseResponse.Error = @{
                    Code = 'NOT_FOUND'
                    Details = 'The requested resource could not be located'
                }
            }
            'Unauthorized' {
                $baseResponse.Success = $false
                $baseResponse.StatusCode = 401
                $baseResponse.Message = 'Authentication required'
                $baseResponse.Error = @{
                    Code = 'UNAUTHORIZED'
                    Details = 'Valid authentication credentials are required'
                }
            }
            'ValidationError' {
                $baseResponse.Success = $false
                $baseResponse.StatusCode = 400
                $baseResponse.Message = 'Validation failed'
                $baseResponse.Error = @{
                    Code = 'VALIDATION_ERROR'
                    Details = 'One or more validation errors occurred'
                    ValidationErrors = @(
                        @{ Field = 'Email'; Message = 'Invalid email format' }
                        @{ Field = 'Age'; Message = 'Age must be between 18 and 65' }
                    )
                }
            }
        }

        return $baseResponse
    }

    # Database result data generation
    static [object[]] CreateDatabaseResults([string]$Table = 'Users', [int]$Count = 10) {
        switch ($Table) {
            'Users' { return [TestDataFactory]::CreateUsers($Count) }
            'Servers' { return [TestDataFactory]::CreateServers($Count) }
            'Logs' { return [TestDataFactory]::CreateLogEntries($Count) }
            default {
                return 1..$Count | ForEach-Object {
                    @{
                        Id = $_
                        Name = "Item $_"
                        Value = "Value $_"
                        CreatedDate = (Get-Date).AddDays(-((Get-Random -Minimum 1 -Maximum 30)))
                    }
                }
            }
        }
    }

    # Performance baseline data
    static [hashtable] CreatePerformanceBaseline([string]$Component = 'General') {
        return @{
            Component = $Component
            LastUpdated = Get-Date
            Baselines = @{
                ExecutionTime = @{
                    SingleItem = [TimeSpan]::FromMilliseconds(100)
                    BatchProcessing = [TimeSpan]::FromSeconds(5)
                    LargeDataset = [TimeSpan]::FromMinutes(2)
                }
                MemoryUsage = @{
                    Baseline = 50MB
                    Maximum = 200MB
                    PerItem = 1KB
                }
                Throughput = @{
                    ItemsPerSecond = 100
                    RequestsPerMinute = 6000
                    ConcurrentUsers = 50
                }
            }
        }
    }

    # Helper methods
    static [string] GetRandomFirstName() {
        $names = @('John', 'Jane', 'Michael', 'Sarah', 'David', 'Lisa', 'Robert', 'Maria', 'James', 'Jennifer',
                  'William', 'Patricia', 'Richard', 'Elizabeth', 'Charles', 'Linda', 'Joseph', 'Barbara',
                  'Thomas', 'Susan', 'Christopher', 'Jessica', 'Daniel', 'Karen', 'Matthew', 'Nancy')
        return Get-Random -InputObject $names
    }

    static [string] GetRandomLastName() {
        $names = @('Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez',
                  'Martinez', 'Hernandez', 'Lopez', 'Gonzalez', 'Wilson', 'Anderson', 'Thomas', 'Taylor',
                  'Moore', 'Jackson', 'Martin', 'Lee', 'Perez', 'Thompson', 'White', 'Harris', 'Sanchez')
        return Get-Random -InputObject $names
    }

    static [object[]] CreateLogEntries([int]$Count) {
        $levels = @('Information', 'Warning', 'Error', 'Debug', 'Verbose')
        $sources = @('Application', 'Security', 'System', 'Database', 'Network')
        $messages = @(
            'User login successful',
            'Database connection established',
            'Configuration updated',
            'Performance threshold exceeded',
            'Security scan completed',
            'Backup operation started',
            'Service restart initiated',
            'Data synchronization completed'
        )

        return 1..$Count | ForEach-Object {
            @{
                Id = $_
                Timestamp = (Get-Date).AddMinutes(-((Get-Random -Minimum 1 -Maximum 1440)))  # Last 24 hours
                Level = Get-Random -InputObject $levels
                Source = Get-Random -InputObject $sources
                Message = Get-Random -InputObject $messages
                UserId = if ((Get-Random -Minimum 1 -Maximum 100) -gt 30) { Get-Random -Minimum 1 -Maximum 50 } else { $null }
                CorrelationId = [System.Guid]::NewGuid().ToString()
            }
        }
    }

    # Clear cache
    static [void] ClearCache() {
        [TestDataFactory]::Cache = @{}
    }

    # Save data to file
    static [void] SaveTestData([string]$Name, [object]$Data, [string]$Format = 'JSON') {
        $filePath = Join-Path ([TestDataFactory]::DataPath) "Generated\$Name.$($Format.ToLower())"

        # Ensure directory exists
        $directory = Split-Path $filePath -Parent
        if (-not (Test-Path $directory)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        switch ($Format.ToUpper()) {
            'JSON' {
                $Data | ConvertTo-Json -Depth 10 | Out-File $filePath -Encoding UTF8
            }
            'CSV' {
                $Data | Export-Csv $filePath -NoTypeInformation -Encoding UTF8
            }
            'PSD1' {
                "@{" | Out-File $filePath -Encoding UTF8
                $Data.GetEnumerator() | ForEach-Object {
                    "    $($_.Key) = '$($_.Value)'" | Out-File $filePath -Append -Encoding UTF8
                }
                "}" | Out-File $filePath -Append -Encoding UTF8
            }
            'XML' {
                $Data | Export-Clixml $filePath
            }
        }
    }
}

# Convenience functions
function New-TestUsers {
    param([int]$Count = 5, [string]$Type = 'Standard')
    return [TestDataFactory]::CreateUsers($Count, $Type)
}

function New-TestServers {
    param([int]$Count = 10, [string]$Environment = 'Mixed')
    return [TestDataFactory]::CreateServers($Count, $Environment)
}

function New-TestConfiguration {
    param([string]$Environment = 'Testing', [string]$Application = 'Default')
    return [TestDataFactory]::CreateConfiguration($Environment, $Application)
}

function New-TestAPIResponse {
    param([string]$Type = 'Success', [object]$Data = $null)
    return [TestDataFactory]::CreateAPIResponse($Type, $Data)
}

function New-TestCredential {
    param([string]$Username = 'testuser', [string]$Password = 'TestPassword123!')
    return New-Object PSCredential($Username, (ConvertTo-SecureString $Password -AsPlainText -Force))
}

function New-MockDateTime {
    param([string]$BaseDate = '2024-01-01', [int]$DaysRange = 30)
    $base = [DateTime]::Parse($BaseDate)
    return $base.AddDays((Get-Random -Minimum 0 -Maximum $DaysRange))
}

function Clear-TestDataCache {
    [TestDataFactory]::ClearCache()
}
```

## Static Test Data Files

### Configuration Files

```powershell
# TestData/Configurations/testing.psd1
@{
    Environment = 'Testing'
    Database = @{
        Server = 'test-db.company.local'
        Database = 'TestDB'
        Timeout = 30
        ConnectionPoolSize = 10
    }
    Logging = @{
        Level = 'Debug'
        Path = 'C:\Logs\Testing'
        RetentionDays = 7
    }
    Security = @{
        RequireSSL = $false
        SessionTimeout = 3600
        MaxLoginAttempts = 5
    }
    Features = @{
        DebugMode = $true
        MockData = $true
        PerformanceProfiling = $true
    }
}
```

### Sample Data Files

```json
// TestData/SampleData/users.json
[
    {
        "id": 1,
        "firstName": "John",
        "lastName": "Doe",
        "email": "john.doe@company.com",
        "department": "IT",
        "active": true,
        "roles": ["User", "Developer"]
    },
    {
        "id": 2,
        "firstName": "Jane",
        "lastName": "Smith",
        "email": "jane.smith@company.com",
        "department": "HR",
        "active": true,
        "roles": ["User", "Manager"]
    }
]
```

## Test Data Best Practices

### Data Isolation

```powershell
BeforeEach {
    # Create isolated test data for each test.
    # Only ONE BeforeEach and ONE AfterEach per block - duplicates throw in Pester 6.
    $script:TestUsers = New-TestUsers -Count 3 -Type 'Standard'
    $script:TestConfig = New-TestConfiguration -Environment 'Testing'
}

AfterEach {
    # Clean up test data
    Clear-TestDataCache
    Remove-Variable -Name 'TestUsers', 'TestConfig' -Scope Script -ErrorAction SilentlyContinue
}
```

The `TestDataFactory` cache is **per-runspace**. Under `Run.Parallel` each test file gets its own
runspace and therefore its own cache, so cached data is never shared between files. Do not rely on
one file warming the cache for another - that was already fragile in Pester 5 and is impossible in
a parallel v6 run.

Use `TestDrive:` for file-based test data rather than `$env:TEMP`. Pester creates and removes it per
container, so it is isolated between files even under parallel:

```powershell
BeforeAll {
    $dataFile = Join-Path $TestDrive 'users.json'
    New-TestUsers -Count 3 | ConvertTo-Json | Set-Content $dataFile
}
```

### Data Validation

```powershell
function Test-TestDataIntegrity {
    param([object[]]$Data, [string]$Type)

    switch ($Type) {
        'Users' {
            $Data | Should-All { $null -ne $_.Id }
            $Data | Should-All { $_.Email -match '^[^@]+@[^@]+\.[^@]+$' }
            $Data | Should-All { -not [string]::IsNullOrWhiteSpace($_.FirstName) }
            $Data | Should-All { -not [string]::IsNullOrWhiteSpace($_.LastName) }
        }
        'Servers' {
            $Data | Should-All { -not [string]::IsNullOrWhiteSpace($_.Name) }
            $Data | Should-All { $_.IPAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' }
            # Should -BeIn has no direct Should-* equivalent - test membership in the filter
            $Data | Should-All { $_.Environment -in @('Production', 'Development', 'Testing', 'Staging') }
        }
    }
}
```

`Should-All` reports which item failed and why, where a `foreach` loop of individual assertions
stops at the first failure and does not tell you the index.

### Performance Test Data

```powershell
function New-PerformanceTestData {
    param([int]$ItemCount = 1000, [string]$DataType = 'Users')

    # Generate large datasets for performance testing
    $data = switch ($DataType) {
        'Users' {
            1..$ItemCount | ForEach-Object {
                [TestDataFactory]::CreateUsers(1, 'Standard')[0]
            }
        }
        'LargeText' {
            1..$ItemCount | ForEach-Object {
                @{
                    Id = $_
                    Content = 'Lorem ipsum dolor sit amet ' * 100  # ~2KB per item
                    Timestamp = Get-Date
                }
            }
        }
    }

    return $data
}
```

### Secure Test Data

```powershell
function New-SecureTestCredentials {
    param([int]$Count = 5)

    # Generate test credentials with secure handling
    return 1..$Count | ForEach-Object {
        @{
            Username = "testuser$_"
            Credential = New-Object PSCredential("testuser$_", (ConvertTo-SecureString "TestPass$_!" -AsPlainText -Force))
            Permissions = @('Read', 'Write', 'Execute')
            ExpirationDate = (Get-Date).AddDays(30)
        }
    }
}
```
