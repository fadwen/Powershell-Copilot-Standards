# Mocking Patterns Guide

Targets **Pester 6.1+**.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## What Changed in Pester 6

### `Assert-MockCalled` and `Assert-VerifiableMock` were removed

Both commands are **gone**. Calling them fails with a command-not-found error.

| Removed | Replacement (classic) | Replacement (v6 syntax) |
| --- | --- | --- |
| `Assert-MockCalled Cmd -Times 1 -Exactly` | `Should -Invoke Cmd -Times 1 -Exactly` | `Should-Invoke Cmd -Times 1 -Exactly` |
| `Assert-MockCalled Cmd -Times 0` | `Should -Not -Invoke Cmd` | `Should-NotInvoke Cmd` |
| `Assert-VerifiableMock` | `Should -InvokeVerifiable` | `Should-Invoke -Verifiable` |

The parameters carry over unchanged: `-Times`, `-Exactly`, `-ParameterFilter`, `-ExclusiveFilter`,
`-ModuleName`, `-Scope`.

### Fall-through to the real command was removed

A mock whose `-ParameterFilter` does not match **no longer quietly calls the real command**. This
made mocks unpredictable and hid missing cases. Define every case you need explicitly:

```powershell
# Pester 5: unmatched calls silently hit the real Get-Content. Pester 6: they hit this mock.
Mock Get-Content { 'default content' } -ModuleName ModuleName
Mock Get-Content { 'special content' } -ParameterFilter { $Path -like '*special*' } -ModuleName ModuleName
```

If a test relied on fall-through, add an explicit default mock, or scope the mock more narrowly so
the real command is genuinely not intercepted.

### Failed mock assertions print the invocation history

When a `Should -Invoke` / `Should-Invoke` assertion fails, Pester prints every recorded call and
marks whether it matched your `-ParameterFilter` - `[*]` for matched, `[ ]` for not:

```text
[-] emails alice exactly twice
 Expected Send-Email to be called 2 times exactly, but was called 1 times
 Performed invocations:
   [*] Send-Email -To 'alice@example.com' -Subject 'Welcome' from Order.Tests.ps1:7
   [ ] Send-Email -To 'bob@example.com'   -Subject 'Receipt' from Order.Tests.ps1:7
```

You no longer need `Write-Host` debugging to work out why a parameter filter did not match.

### Dynamic parameters are handled more robustly

Aliases are matched in `-ParameterFilter`, and mocking falls back gracefully when a command cannot
produce dynamic parameters.

### Mocking inside a module

A mock declared in a test file replaces the command for callers in that file. To replace a function
that a _module's_ code calls - typically a private helper - declare the mock inside
`InModuleScope`, where the module's internal scope is visible:

```powershell
InModuleScope MyModule {
    Mock Get-ServiceStatus { throw 'service unreachable' }

    # Get-Data is public; Get-ServiceStatus is private and never exported
    'Billing', 'Identity' | Get-Data -ErrorAction SilentlyContinue
}
```

Worked instance:
[Module-Structure-Example/Tests](../../../Documentation/Examples/Module-Structure-Example/Tests/)
mocks a private function this way to exercise a per-item failure path.

## Global Mocks (Experimental)

New in Pester 6.1, off by default.

Scoping is the part of mocking that most often goes wrong, and it fails quietly. A mock applies to
calls from the scope that declared it, or from the one module named by `-ModuleName`. A call that
originates anywhere else reaches the **real command**. When the code under test calls a helper module
that calls `Invoke-WebRequest`, mocking `Invoke-WebRequest` in the test file does nothing, the test
still hits the network, and nothing announces it.

`Mock.Global` makes a mock reach the command wherever it is called, from any module or script in the
runspace:

```powershell
$config = New-PesterConfiguration
$config.Mock.Global = $true
```

The mock itself is written exactly as before - one declaration now covers every caller:

```powershell
Mock Invoke-WebRequest { '<html />' }

Get-Data                 # a function in another module that calls Invoke-WebRequest
Should-Invoke Invoke-WebRequest -Times 1
```

### What Changes

| | Default | `Mock.Global = $true` |
| --- | --- | --- |
| Reach | The declaring scope, or the module named by `-ModuleName` | Every module and script in the runspace |
| `-ModuleName` | Selects the scope the mock applies to | A hint used only to resolve the command |
| Lifetime | Removed when the declaring block ends | Unchanged |
| Nested Pester runs | Not visible | Not visible - the mock is tied to the run that created it |

Because `-ModuleName` stops being a scope, existing mocks keep working unchanged. The one behavior
that can move is a mocked command called from a module you did **not** name: that call used to reach
the real command and now gets the mock. That is the change to look for when turning the option on -
in most suites it is also the bug the option exists to prevent.

### Guarding Against A Command Running For Real

The clearest use is proving a destructive or outbound command is never genuinely invoked, without
enumerating every module that might reach it:

```powershell
# Fail loudly on any real network call, from anywhere in the suite
Mock Invoke-RestMethod { throw 'blocked: unmocked network call' }
```

A guard narrowed with `-ParameterFilter` needs one more piece. **`Mock.Global` does not reinstate
fall-through** - the Pester 6 removal described above still applies, so a call that matches no filter
does not reach the real command, it fails:

```text
No mock for command 'Remove-Item' matched the call: none of the parameter filters matched, and there
is no default mock to fall back to. Add a default mock (e.g. `Mock Remove-Item { ... }`) or adjust an
existing -ParameterFilter.
```

Declare the allowed case explicitly alongside the guard:

```powershell
# Any delete outside TestDrive fails the test, wherever it was called from
Mock Remove-Item { throw "blocked: Remove-Item outside TestDrive ($Path)" } `
    -ParameterFilter { $Path -notlike "$TestDrive*" }

# Required: the calls the guard permits still need a mock to land on
Mock Remove-Item { }
```

This is the same rule as everywhere else in Pester 6 - every case a mock is expected to handle must
be declared - and it is easy to miss when writing a guard, because the guard reads as though it only
concerns the calls it names.

### Why The Guard Needs Both Pieces

Run the same guard against a call made from inside another module, with and without the option, and
the two failure modes are opposite:

| | Filter matches (blocked path) | Filter does not match (allowed path) |
| --- | --- | --- |
| `Mock.Global = $false` | **Guard never fires.** The mock does not cover the module, so the real command runs | Real command runs |
| `Mock.Global = $true` | Guard throws, as intended | **Unmatched-mock error.** Not fall-through |

The left column is the reason to turn `Mock.Global` on: without it a guard aimed at "any code under
test" silently does not apply to the module callers it was written for, and a destructive command
runs for real while the test still passes.

The right column is the reason the guard still needs a default mock. Turning the option on converts
the permitted calls from "reach the real command" into "error", so a guard that looked complete
before now fails on traffic it was never meant to block.

The apparent fall-through with the option off is not fall-through at all - it is the mock failing to
reach that caller. Nothing restores Pester 5's fall-through behavior; `Mock.Global` is the only
setting in the `Mock` configuration section.

### Calling the Real Command From Inside a Mock

When the permitted calls must genuinely run, the default mock has to invoke the original command.
Capture it with `Get-Command` in a `BeforeAll` - **before** the mock is defined, or `Get-Command`
resolves to the mock - and call it with `&`, forwarding the automatic `$PesterBoundParameters`
hashtable that Pester exposes inside a `-MockWith` body:

```powershell
BeforeAll {
    $originalRemoveItem = Get-Command Remove-Item -CommandType Cmdlet
}

It 'deletes inside TestDrive and blocks everything else' {
    Mock Remove-Item { throw "blocked: Remove-Item outside TestDrive ($Path)" } `
        -ParameterFilter { $Path -notlike "$TestDrive*" }

    # The permitted calls really delete
    Mock Remove-Item { & $originalRemoveItem @PesterBoundParameters }

    # ...
}
```

`$PesterBoundParameters` is the hashtable of parameters the caller bound, so splatting it forwards
the call unchanged. This is the supported way to wrap rather than replace a command - decorating its
output, counting calls while keeping real behavior, or letting a filtered subset through.

`$PSBoundParameters` is **not** the equivalent inside a mock body and does not carry the caller's
arguments; use `$PesterBoundParameters`.

### Status

`Mock.Global` is experimental and may change. The Pester team has said it wants this to become the
default in v7 and is collecting reports either way - including "turned it on, nothing changed" -
through the [Pester issue tracker](https://github.com/pester/Pester/issues).

Configure it per run rather than per file: there is no file-level directive to opt in or out, so a
suite either runs with global mocks or it does not.

## Advanced Mocking Strategies

### Context-Aware Mocking

Create sophisticated mocks that respond differently based on parameters:

```powershell
BeforeAll {
    # API endpoint mocking with different responses
    Mock Invoke-RestMethod {
        param($Uri, $Method, $Body, $Headers)

        switch -Regex ($Uri) {
            '/api/users/\d+$' {
                if ($Method -eq 'GET') {
                    return @{
                        Id = 123
                        Name = 'Test User'
                        Email = 'test@example.com'
                        Status = 'Active'
                    }
                }
                elseif ($Method -eq 'PUT') {
                    $userData = $Body | ConvertFrom-Json
                    return @{
                        Id = 123
                        Name = $userData.Name
                        Email = $userData.Email
                        Status = 'Updated'
                        LastModified = Get-Date
                    }
                }
                elseif ($Method -eq 'DELETE') {
                    return @{ Success = $true; Message = 'User deleted' }
                }
            }
            '/api/users$' {
                if ($Method -eq 'GET') {
                    return @{
                        Users = @(
                            @{ Id = 1; Name = 'User 1'; Status = 'Active' }
                            @{ Id = 2; Name = 'User 2'; Status = 'Inactive' }
                        )
                        TotalCount = 2
                        Page = 1
                    }
                }
                elseif ($Method -eq 'POST') {
                    $newUser = $Body | ConvertFrom-Json
                    return @{
                        Id = 999
                        Name = $newUser.Name
                        Email = $newUser.Email
                        Status = 'Created'
                        CreatedDate = Get-Date
                    }
                }
            }
            '/api/health' {
                return @{ Status = 'Healthy'; Timestamp = Get-Date; Version = '1.0.0' }
            }
            default {
                throw [System.Net.WebException]::new("Not Found: $Uri", [System.Net.WebExceptionStatus]::ProtocolError)
            }
        }
    } -ModuleName ModuleName
}
```

### Database Connection Mocking

Mock database operations with realistic behavior:

```powershell
BeforeAll {
    # Mock database connection with state management
    $script:MockDatabase = @{
        Connected = $false
        TransactionActive = $false
        Data = @{
            Users = @()
            Products = @()
        }
    }

    Mock Connect-Database {
        param($ConnectionString, $Credential)

        if ($ConnectionString -match 'invalid') {
            throw [System.Data.SqlClient.SqlException]::new('Invalid connection string')
        }

        if ($Credential -and $Credential.UserName -eq 'invaliduser') {
            throw [System.Data.SqlClient.SqlException]::new('Login failed for user')
        }

        $script:MockDatabase.Connected = $true
        return @{
            ConnectionId = [System.Guid]::NewGuid()
            ServerVersion = '14.0.3048'
            Database = 'TestDB'
            State = 'Open'
        }
    } -ModuleName ModuleName

    Mock Invoke-DatabaseQuery {
        param($Query, $Parameters = @{})

        if (-not $script:MockDatabase.Connected) {
            throw [System.InvalidOperationException]::new('Database connection not established')
        }

        # Parse simple SQL queries
        switch -Regex ($Query) {
            'SELECT.*FROM Users' {
                if ($Query -match 'WHERE Id = @Id') {
                    $userId = $Parameters.Id
                    return $script:MockDatabase.Data.Users | Where-Object { $_.Id -eq $userId }
                }
                return $script:MockDatabase.Data.Users
            }
            'INSERT INTO Users' {
                $newUser = @{
                    Id = ($script:MockDatabase.Data.Users.Count + 1)
                    Name = $Parameters.Name
                    Email = $Parameters.Email
                    CreatedDate = Get-Date
                }
                $script:MockDatabase.Data.Users += $newUser
                return @{ RowsAffected = 1; Identity = $newUser.Id }
            }
            'UPDATE Users' {
                $user = $script:MockDatabase.Data.Users | Where-Object { $_.Id -eq $Parameters.Id }
                if ($user) {
                    $user.Name = $Parameters.Name ?? $user.Name
                    $user.Email = $Parameters.Email ?? $user.Email
                    $user.ModifiedDate = Get-Date
                    return @{ RowsAffected = 1 }
                }
                return @{ RowsAffected = 0 }
            }
            'DELETE FROM Users' {
                $originalCount = $script:MockDatabase.Data.Users.Count
                $script:MockDatabase.Data.Users = $script:MockDatabase.Data.Users | Where-Object { $_.Id -ne $Parameters.Id }
                return @{ RowsAffected = $originalCount - $script:MockDatabase.Data.Users.Count }
            }
            default {
                throw [System.Data.SqlClient.SqlException]::new("Invalid SQL syntax: $Query")
            }
        }
    } -ModuleName ModuleName

    Mock Start-DatabaseTransaction {
        if (-not $script:MockDatabase.Connected) {
            throw [System.InvalidOperationException]::new('Database connection not established')
        }
        $script:MockDatabase.TransactionActive = $true
        return @{ TransactionId = [System.Guid]::NewGuid() }
    } -ModuleName ModuleName

    Mock Commit-DatabaseTransaction {
        $script:MockDatabase.TransactionActive = $false
    } -ModuleName ModuleName

    Mock Rollback-DatabaseTransaction {
        $script:MockDatabase.TransactionActive = $false
        # In a real mock, you might restore previous state here
    } -ModuleName ModuleName
}
```

### File System Mocking

Mock file system operations with realistic behavior:

```powershell
BeforeAll {
    # Mock file system with in-memory storage
    $script:MockFileSystem = @{
        Files = @{}
        Directories = @('C:\', 'C:\Temp\', 'C:\Windows\')
    }

    Mock Test-Path {
        param($Path)

        $normalizedPath = $Path.Replace('/', '\').TrimEnd('\')

        # Check if it's a file
        if ($script:MockFileSystem.Files.ContainsKey($normalizedPath)) {
            return $true
        }

        # Check if it's a directory
        return $script:MockFileSystem.Directories -contains "$normalizedPath\"
    } -ModuleName ModuleName

    Mock Get-Content {
        param($Path, $Raw, $Encoding = 'UTF8')

        $normalizedPath = $Path.Replace('/', '\')

        if (-not $script:MockFileSystem.Files.ContainsKey($normalizedPath)) {
            throw [System.IO.FileNotFoundException]::new("File not found: $Path")
        }

        $content = $script:MockFileSystem.Files[$normalizedPath]

        if ($Raw) {
            return $content
        } else {
            return $content -split "`r?`n"
        }
    } -ModuleName ModuleName

    Mock Set-Content {
        param($Path, $Value, $Encoding = 'UTF8')

        $normalizedPath = $Path.Replace('/', '\')
        $directory = Split-Path $normalizedPath -Parent

        # Ensure directory exists
        if ($directory -and -not ($script:MockFileSystem.Directories -contains "$directory\")) {
            throw [System.IO.DirectoryNotFoundException]::new("Directory not found: $directory")
        }

        $script:MockFileSystem.Files[$normalizedPath] = $Value -join "`r`n"
        return @{ Length = $script:MockFileSystem.Files[$normalizedPath].Length }
    } -ModuleName ModuleName

    Mock New-Item {
        param($Path, $ItemType, $Force)

        $normalizedPath = $Path.Replace('/', '\')

        if ($ItemType -eq 'Directory') {
            if (-not ($script:MockFileSystem.Directories -contains "$normalizedPath\")) {
                $script:MockFileSystem.Directories += "$normalizedPath\"
            }
            return @{ FullName = $normalizedPath; PSIsContainer = $true }
        } else {
            $script:MockFileSystem.Files[$normalizedPath] = ''
            return @{ FullName = $normalizedPath; PSIsContainer = $false }
        }
    } -ModuleName ModuleName

    Mock Remove-Item {
        param($Path, $Recurse, $Force)

        $normalizedPath = $Path.Replace('/', '\')

        # Remove file
        if ($script:MockFileSystem.Files.ContainsKey($normalizedPath)) {
            $script:MockFileSystem.Files.Remove($normalizedPath)
            return
        }

        # Remove directory
        $directoryPath = "$normalizedPath\"
        if ($script:MockFileSystem.Directories -contains $directoryPath) {
            if ($Recurse) {
                # Remove all files and subdirectories
                $filesToRemove = $script:MockFileSystem.Files.Keys | Where-Object { $_.StartsWith($normalizedPath) }
                foreach ($file in $filesToRemove) {
                    $script:MockFileSystem.Files.Remove($file)
                }

                $dirsToRemove = $script:MockFileSystem.Directories | Where-Object { $_.StartsWith($directoryPath) }
                foreach ($dir in $dirsToRemove) {
                    $script:MockFileSystem.Directories = $script:MockFileSystem.Directories | Where-Object { $_ -ne $dir }
                }
            }
            $script:MockFileSystem.Directories = $script:MockFileSystem.Directories | Where-Object { $_ -ne $directoryPath }
        }
    } -ModuleName ModuleName
}
```

### Network Service Mocking

Mock network operations with failure simulation:

```powershell
BeforeAll {
    # Mock network services with failure simulation
    Mock Test-NetConnection {
        param($ComputerName, $Port = 80, $InformationLevel = 'Detailed')

        # Simulate different network conditions
        switch ($ComputerName) {
            'unreachable.test' {
                return @{
                    ComputerName = $ComputerName
                    RemoteAddress = $null
                    PingSucceeded = $false
                    TcpTestSucceeded = $false
                }
            }
            'slow.test' {
                Start-Sleep -Milliseconds 2000  # Simulate slow connection
                return @{
                    ComputerName = $ComputerName
                    RemoteAddress = '192.168.1.100'
                    PingSucceeded = $true
                    TcpTestSucceeded = $true
                    PingReplyDetails = @{ RoundtripTime = 2000 }
                }
            }
            { $_ -match '\.local$' } {
                return @{
                    ComputerName = $ComputerName
                    RemoteAddress = '192.168.1.50'
                    PingSucceeded = $true
                    TcpTestSucceeded = $true
                    PingReplyDetails = @{ RoundtripTime = 15 }
                }
            }
            default {
                return @{
                    ComputerName = $ComputerName
                    RemoteAddress = '8.8.8.8'
                    PingSucceeded = $true
                    TcpTestSucceeded = $true
                    PingReplyDetails = @{ RoundtripTime = 45 }
                }
            }
        }
    } -ModuleName ModuleName

    Mock Invoke-WebRequest {
        param($Uri, $Method = 'GET', $Body, $Headers = @{}, $TimeoutSec = 30)

        # Simulate different response scenarios
        switch -Regex ($Uri) {
            'timeout\.test' {
                Start-Sleep -Seconds ($TimeoutSec + 1)
                throw [System.Net.WebException]::new('The operation has timed out', [System.Net.WebExceptionStatus]::Timeout)
            }
            'server-error\.test' {
                throw [System.Net.WebException]::new('The remote server returned an error: (500) Internal Server Error', [System.Net.WebExceptionStatus]::ProtocolError)
            }
            'not-found\.test' {
                throw [System.Net.WebException]::new('The remote server returned an error: (404) Not Found', [System.Net.WebExceptionStatus]::ProtocolError)
            }
            'auth\.test' {
                if (-not $Headers.ContainsKey('Authorization')) {
                    throw [System.Net.WebException]::new('The remote server returned an error: (401) Unauthorized', [System.Net.WebExceptionStatus]::ProtocolError)
                }
                # Return success response
                return @{
                    StatusCode = 200
                    StatusDescription = 'OK'
                    Content = '{"authenticated": true, "user": "testuser"}'
                    Headers = @{ 'Content-Type' = 'application/json' }
                }
            }
            default {
                # Return successful response
                $responseContent = switch ($Method) {
                    'GET' { '{"data": "sample response"}' }
                    'POST' { '{"id": 12345, "status": "created"}' }
                    'PUT' { '{"id": 12345, "status": "updated"}' }
                    'DELETE' { '{"status": "deleted"}' }
                    default { '{"status": "ok"}' }
                }

                return @{
                    StatusCode = 200
                    StatusDescription = 'OK'
                    Content = $responseContent
                    Headers = @{ 'Content-Type' = 'application/json' }
                }
            }
        }
    } -ModuleName ModuleName
}
```

### External Command Mocking

Mock external executable commands:

```powershell
BeforeAll {
    # Mock external commands with different exit codes
    Mock Start-Process {
        param($FilePath, $ArgumentList, $Wait, $PassThru, $RedirectStandardOutput, $RedirectStandardError)

        $command = $FilePath
        $args = $ArgumentList -join ' '

        # Simulate different command behaviors
        switch -Regex ("$command $args") {
            'git status' {
                $output = @"
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

        modified:   src/module.ps1

no changes added to commit (use "git add" or "git commit -a")
"@
                if ($RedirectStandardOutput) {
                    $output | Out-File $RedirectStandardOutput
                }
                return @{ ExitCode = 0; ProcessName = 'git' }
            }
            'git clone.*invalid-repo' {
                $error = "fatal: repository 'invalid-repo' does not exist"
                if ($RedirectStandardError) {
                    $error | Out-File $RedirectStandardError
                }
                return @{ ExitCode = 128; ProcessName = 'git' }
            }
            'docker ps' {
                $output = @"
CONTAINER ID   IMAGE     COMMAND                  CREATED       STATUS       PORTS     NAMES
abc123def456   nginx     "/docker-entrypoint.…"   2 hours ago   Up 2 hours   80/tcp    web-server
def456ghi789   redis     "docker-entrypoint.s…"   2 hours ago   Up 2 hours   6379/tcp  redis-cache
"@
                if ($RedirectStandardOutput) {
                    $output | Out-File $RedirectStandardOutput
                }
                return @{ ExitCode = 0; ProcessName = 'docker' }
            }
            'powershell.*-File.*test-script' {
                # Simulate script execution
                if ($args -match 'fail') {
                    return @{ ExitCode = 1; ProcessName = 'powershell' }
                }
                return @{ ExitCode = 0; ProcessName = 'powershell' }
            }
            default {
                # Unknown command
                return @{ ExitCode = 127; ProcessName = $command }
            }
        }
    } -ModuleName ModuleName

    # Mock Windows services
    Mock Get-Service {
        param($Name, $ComputerName = $env:COMPUTERNAME)

        $mockServices = @{
            'Spooler' = @{ Name = 'Spooler'; Status = 'Running'; StartType = 'Automatic' }
            'BITS' = @{ Name = 'BITS'; Status = 'Running'; StartType = 'Manual' }
            'Fax' = @{ Name = 'Fax'; Status = 'Stopped'; StartType = 'Manual' }
            'InvalidService' = $null
        }

        if ($Name) {
            $service = $mockServices[$Name]
            if ($service) {
                return [PSCustomObject]$service
            } else {
                throw [Microsoft.PowerShell.Commands.ServiceCommandException]::new("Cannot find any service with service name '$Name'.")
            }
        } else {
            return $mockServices.Values | Where-Object { $_ -ne $null } | ForEach-Object { [PSCustomObject]$_ }
        }
    } -ModuleName ModuleName
}
```

## Mock Validation Patterns

### Parameter Filter Testing

Validate that mocks are called with correct parameters:

```powershell
Context "Mock Parameter Validation" {
    It "Should call API with correct parameters" {
        $testData = @{ Name = 'Test'; Value = 'Data' }

        Function-Name -Data $testData -Endpoint 'https://api.test.com'

        Should-Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName ModuleName -ParameterFilter {
            $Uri -eq 'https://api.test.com' -and
            $Method -eq 'POST' -and
            ($Body | ConvertFrom-Json).Name -eq 'Test'
        }
    }

    It "Should handle multiple calls with different parameters" {
        $endpoints = @('https://api1.test.com', 'https://api2.test.com')

        foreach ($endpoint in $endpoints) {
            Function-Name -Endpoint $endpoint
        }

        Should-Invoke Invoke-RestMethod -Times 2 -Exactly -ModuleName ModuleName
        Should-Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName ModuleName -ParameterFilter {
            $Uri -eq 'https://api1.test.com'
        }
        Should-Invoke Invoke-RestMethod -Times 1 -Exactly -ModuleName ModuleName -ParameterFilter {
            $Uri -eq 'https://api2.test.com'
        }
    }

    It "Should not call the destructive command in WhatIf mode" {
        Function-Name -Path 'C:\Temp\file.txt' -WhatIf

        Should-NotInvoke Remove-Item -ModuleName ModuleName
    }

    It "Should call the API only for allowed endpoints" {
        Function-Name -Endpoint 'https://api1.test.com'

        # -ExclusiveFilter fails if ANY recorded call does not match the filter
        Should-Invoke Invoke-RestMethod -ModuleName ModuleName -ExclusiveFilter {
            $Uri -like 'https://api1.*'
        }
    }
}
```

Note the parameter shape: `-Times 1 -Exactly`, not `-Exactly 1`. `-Exactly` is a switch that changes
`-Times` from "at least" to "exactly". `Should-Invoke Cmd -Exactly 1` binds `1` positionally to
`-Times` and happens to work, but writing it out is clearer and matches the classic syntax.

### Asserting a Mock Was Not Called

`Should-NotInvoke` replaces `Should -Not -Invoke` and `Assert-MockCalled -Times 0`. This is the
assertion most often missing from error-handling tests - proving the failure path stopped before the
destructive call is usually more valuable than proving it threw:

```powershell
It "Should not write results when validation fails" {
    Mock Write-Result { } -ModuleName ModuleName

    { Function-Name -ParameterName '' } | Should-Throw

    Should-NotInvoke Write-Result -ModuleName ModuleName
}
```

### Mock Call Sequence Validation

Ensure mocks are called in the correct order:

```powershell
Context "Mock Call Sequence" {
    BeforeEach {
        $script:CallSequence = @()

        Mock Connect-Database {
            $script:CallSequence += 'Connect'
            return @{ Connected = $true }
        } -ModuleName ModuleName

        Mock Start-DatabaseTransaction {
            $script:CallSequence += 'StartTransaction'
            return @{ TransactionId = '12345' }
        } -ModuleName ModuleName

        Mock Invoke-DatabaseQuery {
            $script:CallSequence += 'Query'
            return @{ Success = $true }
        } -ModuleName ModuleName

        Mock Commit-DatabaseTransaction {
            $script:CallSequence += 'Commit'
        } -ModuleName ModuleName

        Mock Disconnect-Database {
            $script:CallSequence += 'Disconnect'
        } -ModuleName ModuleName
    }

    It "Should call database operations in correct sequence" {
        Function-Name -DatabaseOperation 'UpdateUser'

        # Should-BeCollection compares item by item and reports the first differing index
        $script:CallSequence |
            Should-BeCollection @('Connect', 'StartTransaction', 'Query', 'Commit', 'Disconnect')
    }
}
```

`Should-BeCollection` is the right assertion here rather than `Should-Be`: it compares element by
element and names the index that diverged, instead of dumping two flattened strings at you.

## Mock Best Practices

### Isolated Mock Scope

Keep mocks isolated between tests:

```powershell
Describe "Function Tests" {
    Context "Success Scenarios" {
        BeforeEach {
            Mock External-Service { return @{ Success = $true } } -ModuleName ModuleName
        }

        # Tests using success mock
    }

    Context "Failure Scenarios" {
        BeforeEach {
            Mock External-Service { throw 'Service unavailable' } -ModuleName ModuleName
        }

        # Tests using failure mock
    }
}
```

Each `Context` gets its own `BeforeEach`. Pester 6 **throws** on two `BeforeEach` blocks in the
_same_ block, so when you need several groups of mocks, split them into separate `Context` blocks
rather than adding a second setup block.

### Mocks Do Not Cross Files

Pester 6 discovers and runs one file at a time, and under `Run.Parallel` each file gets its own
runspace. A mock defined in one test file is never visible to another. Define every mock a file
needs inside that file. For mock setup shared across many files, dot-source a shared mock factory
from a `Pester.BeforeContainer.ps1` at the repository root - but note that `Mock` itself must still
be called inside a `Describe`/`Context`/`BeforeAll` scope:

```powershell
# TestHelpers/MockFactory.ps1 - dot-sourced from Pester.BeforeContainer.ps1
function Set-StandardExternalMock {
    param([string]$ModuleName)
    Mock Invoke-RestMethod { @{ Status = 'Healthy' } } -ModuleName $ModuleName
    Mock Write-Verbose { } -ModuleName $ModuleName
}
```

```powershell
# In each test file
BeforeAll {
    Set-StandardExternalMock -ModuleName ModuleName
}
```

### Realistic Mock Data

Use realistic data structures in mocks:

```powershell
BeforeAll {
    # Load realistic test data
    $script:TestUsers = @(
        @{ Id = 1; Name = 'John Doe'; Email = 'john.doe@example.com'; Department = 'IT'; Active = $true }
        @{ Id = 2; Name = 'Jane Smith'; Email = 'jane.smith@example.com'; Department = 'HR'; Active = $true }
        @{ Id = 3; Name = 'Bob Johnson'; Email = 'bob.johnson@example.com'; Department = 'Finance'; Active = $false }
    )

    Mock Get-ADUser {
        param($Identity, $Properties)

        $user = $script:TestUsers | Where-Object { $_.Name -eq $Identity -or $_.Id -eq $Identity }
        if ($user) {
            return [PSCustomObject]$user
        } else {
            throw [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]::new("User '$Identity' not found")
        }
    } -ModuleName ModuleName
}
```

### Mock Cleanup

Ensure proper mock cleanup:

```powershell
AfterEach {
    # Reset mock state if needed
    $script:MockDatabase = @{
        Connected = $false
        Data = @{}
    }

    # Clear any temporary files created by mocks
    Get-ChildItem -Path $env:TEMP -Filter "MockTest*" | Remove-Item -Force -ErrorAction SilentlyContinue
}
```
