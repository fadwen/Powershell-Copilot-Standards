# Security Test Template

Targets **Pester 6.1+**. Uses the `Should-*` assertion syntax - see
[Assertion Guide](./assertion-guide.md).

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Standard Security Test Structure

Use this template for validating security controls and input sanitization:

```powershell
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0' }

BeforeDiscovery {
    # Attack-pattern data drives -ForEach, so it MUST be built at discovery time.
    # BeforeAll runs at RUN time - too late. A variable defined there is $null
    # during discovery, and $null piped through ForEach-Object yields exactly one
    # iteration, so the suite silently collapses to a single bogus test named
    # "rejects: $null" that asserts nothing about any real attack pattern.
    # Nothing fails; the run just reports green having tested nothing.
    # See "Discovery-Time Data" below.
    $MaliciousInputPatterns = @(
        "'; DROP TABLE Users; --"
        "../../../etc/passwd"
        "<script>alert('xss')</script>"
        '$(Get-Process)'
        "Invoke-Expression 'malicious code'"
        "& cmd.exe /c dir"
        '$(Get-Content secrets.txt)'
    )

    $PathTraversalPatterns = @(
        "..\..\Windows\System32\config"
        "../../../../etc/shadow"
        "..\..\..\secrets\passwords.txt"
        "C:\Windows\System32\SAM"
    )

    $InvalidEmailPatterns = @(
        "notanemail"
        "@domain.com"
        "user@"
        "user..name@domain.com"
        "user@domain"
    )

    $CommandInjectionPatterns = @(
        "normalvalue; Remove-Item C:\temp\*"
        'value$(Get-Process)'
        "value & dir"
        "value | Get-Content secrets.txt"
    )
}

BeforeAll {
    # Import module under test. Each file is self-contained in Pester 6.
    $ModulePath = Join-Path $PSScriptRoot '..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force

    # Runtime-only configuration
    $SecurityConfig = @{
        TestCredentials = @{
            Valid = @{
                Username = "testuser"
                Password = "TestPassword123!"
            }
            Invalid = @{
                Username = "invaliduser"
                Password = "wrongpassword"
            }
        }
    }
}

Describe "Security Tests" -Tag "Security", "InputValidation" {
    Context "Input Validation and Sanitization" {
        It "Should reject malicious input pattern: <MaliciousInput>" -ForEach $MaliciousInputPatterns.ForEach({
            @{ MaliciousInput = $_ }
        }) {
            { Function-Name -ParameterName $MaliciousInput } |
                Should-Throw -ExceptionMessage '*invalid characters*'
        }

        It "Should sanitize file path against traversal: <UnsafePath>" -ForEach $PathTraversalPatterns.ForEach({
            @{ UnsafePath = $_ }
        }) {
            { Function-Name -FilePath $UnsafePath } |
                Should-Throw -ExceptionMessage '*invalid path*'
        }

        It "Should reject invalid email format: <InvalidEmail>" -ForEach $InvalidEmailPatterns.ForEach({
            @{ InvalidEmail = $_ }
        }) {
            { Function-Name -EmailAddress $InvalidEmail } |
                Should-Throw -ExceptionMessage '*invalid email*'
        }

        It "Should prevent command injection: <Injection>" -ForEach $CommandInjectionPatterns.ForEach({
            @{ Injection = $_ }
        }) {
            { Function-Name -ParameterName $Injection } |
                Should-Throw -ExceptionMessage '*invalid characters*'
        }

        It "Should validate parameter length limits" {
            $oversizedInput = "x" * 10000  # 10KB string

            { Function-Name -ParameterName $oversizedInput } |
                Should-Throw -ExceptionMessage '*exceeds maximum length*'
        }

        It "Should reject <Description> input" -ForEach @(
            @{ Description = 'null';             Value = $null; Expected = '*cannot be null*' }
            @{ Description = 'empty';            Value = '';    Expected = '*cannot be empty*' }
            @{ Description = 'whitespace-only';  Value = '   '; Expected = '*cannot be empty*' }
        ) {
            { Function-Name -ParameterName $Value } |
                Should-Throw -ExceptionMessage $Expected
        }
    }

    Context "Credential Handling Security" {
        It "Should not expose credentials in logs or output" {
            $testCredential = New-Object PSCredential(
                $SecurityConfig.TestCredentials.Valid.Username,
                (ConvertTo-SecureString $SecurityConfig.TestCredentials.Valid.Password -AsPlainText -Force)
            )

            # Capture all output streams
            $allOutput = Function-Name -Credential $testCredential -Verbose -Debug 4>&1 5>&1 6>&1

            # Convert all output to string for analysis
            $outputText = $allOutput | Out-String

            # Ensure credentials are not exposed anywhere.
            # Escape the values - they are data, not patterns.
            $outputText | Should-NotMatchString ([regex]::Escape($SecurityConfig.TestCredentials.Valid.Username))
            $outputText | Should-NotMatchString ([regex]::Escape($SecurityConfig.TestCredentials.Valid.Password))
        }

        It "Should handle SecureString parameters securely" {
            $secureString = ConvertTo-SecureString "SecretValue123" -AsPlainText -Force

            # Function should accept SecureString without exposing value
            $result = Function-Name -SecureParameter $secureString -Verbose 4>&1

            # Verify SecureString value is not exposed in verbose output
            ($result | Out-String) | Should-NotMatchString 'SecretValue123'
        }

        It "Should validate credential authentication" {
            $validCredential = New-Object PSCredential(
                $SecurityConfig.TestCredentials.Valid.Username,
                (ConvertTo-SecureString $SecurityConfig.TestCredentials.Valid.Password -AsPlainText -Force)
            )

            $invalidCredential = New-Object PSCredential(
                $SecurityConfig.TestCredentials.Invalid.Username,
                (ConvertTo-SecureString $SecurityConfig.TestCredentials.Invalid.Password -AsPlainText -Force)
            )

            # Valid credentials should work. There is no Should-NotThrow -
            # call it directly; an unhandled exception fails the test.
            Function-Name -Credential $validCredential

            # Invalid credentials should fail gracefully
            { Function-Name -Credential $invalidCredential } |
                Should-Throw -ExceptionMessage '*authentication*'
        }

        It "Should implement secure credential caching" {
            $testCredential = New-Object PSCredential(
                "cachetest",
                (ConvertTo-SecureString "CachePassword123" -AsPlainText -Force)
            )

            # First call - should cache credential securely
            Function-Name -Credential $testCredential -CacheCredentials

            # Verify credential is cached but not exposed
            $cacheContent = Get-CredentialCache -ErrorAction SilentlyContinue
            if (-not $cacheContent) {
                Set-ItResult -Inconclusive -Because 'no credential cache was produced to inspect'
            }

            ($cacheContent | Out-String) | Should-NotMatchString 'CachePassword123'
            ($cacheContent | Out-String) | Should-NotMatchString 'cachetest'
        }
    }

    Context "Access Control and Authorization" {
        It "Should deny access when the role is insufficient" {
            Mock Get-CurrentUserRole { 'User' }

            { Function-Name -RequiredRole 'Administrator' } |
                Should-Throw -ExceptionMessage '*insufficient privileges*'
        }

        It "Should allow access when the role is sufficient" {
            Mock Get-CurrentUserRole { 'Administrator' }

            Function-Name -RequiredRole 'Administrator'
        }

        It "Should not perform the privileged action when denied" {
            Mock Get-CurrentUserRole { 'User' }
            Mock Invoke-PrivilegedAction { }

            { Function-Name -RequiredRole 'Administrator' } | Should-Throw

            # The assertion that actually matters: the action never ran
            Should-NotInvoke Invoke-PrivilegedAction
        }

        It "Should validate file system permissions" {
            $restrictedPath = "C:\Windows\System32\config"

            # Should check permissions before attempting access
            { Function-Name -Path $restrictedPath } |
                Should-Throw -ExceptionMessage '*access denied*'
        }

        It "Should reject an invalid session" {
            Mock Get-CurrentSession { $null }

            { Function-Name -RequireValidSession } |
                Should-Throw -ExceptionMessage '*invalid session*'
        }

        It "Should accept a valid session" {
            Mock Get-CurrentSession { @{ Valid = $true; UserId = 'testuser' } }

            Function-Name -RequireValidSession
        }
    }

    Context "Data Protection and Encryption" {
        It "Should encrypt sensitive data at rest" {
            $sensitiveData = "Confidential Information 12345"

            $result = Function-Name -SensitiveData $sensitiveData -EncryptData

            # Verify data is encrypted (not plaintext)
            $result.EncryptedData | Should-NotMatchString 'Confidential Information'
            $result.EncryptedData | Should-NotBeEmptyString

            # Verify encryption metadata is present
            $result.EncryptionAlgorithm | Should-NotBeEmptyString
            $result.IV | Should-NotBeNull
        }

        It "Should implement secure data transmission" {
            # Mock secure transmission
            Mock Invoke-SecureTransmission {
                param($Data, $Endpoint)

                # Verify data is encrypted before transmission
                if ($Data -match "plaintext") {
                    throw "Data not encrypted for transmission"
                }

                return @{ Success = $true; Encrypted = $true }
            }

            $testData = "Sensitive transmission data"
            $result = Function-Name -TransmitData $testData -Endpoint "https://secure-api.test"

            $result.Success   | Should-BeTrue
            $result.Encrypted | Should-BeTrue
        }

        It "Should securely hash passwords" {
            $password = "UserPassword123!"

            $result = Function-Name -HashPassword $password

            # Verify password is hashed, not stored in plaintext
            $result.HashedPassword | Should-NotMatchString ([regex]::Escape($password))
            $result.HashedPassword | Should-NotBeEmptyString

            # Verify salt is used
            $result.Salt | Should-NotBeEmptyString

            # Verify hash algorithm is secure.
            # Should -BeIn has no direct Should-* equivalent; Should-Any over the
            # allow-list expresses the same intent.
            @('SHA256', 'SHA512', 'bcrypt', 'scrypt', 'PBKDF2') |
                Should-Any { $_ -eq $result.Algorithm }
        }
    }

    Context "Audit and Compliance" {
        It "Should log security-relevant events" {
            # Clear any existing security logs
            Clear-SecurityLog -ErrorAction SilentlyContinue

            # Perform operation that should generate security log
            Function-Name -SecuritySensitiveOperation -UserId "testuser"

            # Verify security event was logged
            $securityLogs = Get-SecurityLog -Recent 1
            $securityLogs | Should-NotBeNull
            $securityLogs[0].EventType | Should-MatchString 'Security'
            $securityLogs[0].UserId | Should-Be 'testuser'
        }

        It "Should implement data retention policies" {
            $testData = @{
                Id = [System.Guid]::NewGuid()
                Data = "Test data for retention"
                RetentionPeriod = [TimeSpan]::FromDays(30)
            }

            # Store data with retention policy
            Function-Name -StoreData $testData

            # Verify retention metadata is set
            $storedData = Get-StoredData -Id $testData.Id
            $storedData.ExpirationDate | Should-BeAfter (Get-Date)
            $storedData.ExpirationDate | Should-BeBefore (Get-Date).AddDays(30)
        }

        It "Should support compliance data export" {
            # Generate test compliance data
            1..5 | ForEach-Object {
                Function-Name -CreateComplianceRecord -UserId "user$_" -Action "TestAction$_"
            }

            # Export compliance data
            $exportResult = Function-Name -ExportComplianceData -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date)

            # Verify export contains required fields.
            # There is no Should -HaveProperty operator in Pester - that was never real.
            # Assert the shape instead.
            $exportResult | Should-NotBeNull
            $exportResult.Records | Should-BeCollection -Count 5
            $exportResult.Records | Should-All {
                $null -ne $_.UserId -and $null -ne $_.Action -and $null -ne $_.Timestamp
            }
        }
    }

    Context "Error Handling Security" {
        It "Should not expose sensitive information in error messages" {
            $sensitiveConnectionString = "Server=secret.db.com;Database=confidential;User=admin;Password=secret123"

            # Capture the error explicitly. A bare try/catch with assertions only in
            # the catch block passes silently when the function does NOT throw -
            # the test then proves nothing.
            $thrown = $null
            try {
                Function-Name -ConnectionString $sensitiveConnectionString -ForceError
            }
            catch {
                $thrown = $_
            }

            $thrown | Should-NotBeNull -Because 'the function was expected to fail'
            $thrown.Exception.Message | Should-NotMatchString 'secret\.db\.com'
            $thrown.Exception.Message | Should-NotMatchString 'secret123'
            $thrown.Exception.Message | Should-NotMatchString 'confidential'
        }

        It "Should implement secure error logging" {
            # Generate an error condition
            { Function-Name -CauseSecurityError -ErrorAction Stop } | Should-Throw

            # Error should be logged securely without exposing sensitive details
            $errorLogs = Get-ErrorLog -Recent 1
            $errorLogs[0].Message | Should-NotBeEmptyString
            $errorLogs[0].SanitizedForSecurity | Should-BeTrue
        }
    }
}
```

## Pester 6 Notes for Security Tests

### Discovery-Time Data

Attack-pattern lists drive `-ForEach`, so they must exist at **discovery** time. Put them in
`BeforeDiscovery`, never `BeforeAll`.

This matters more for security suites than anywhere else, because the failure is silent and looks
like success:

```powershell
# WRONG - $SecurityConfig is $null during discovery.
# $null piped through ForEach-Object yields ONE iteration, so this generates a
# single test named "rejects: $null" that exercises no attack pattern at all.
# The run reports green. Nothing was tested.
BeforeAll {
    $SecurityConfig = @{ MaliciousInputPatterns = @("'; DROP TABLE Users; --", '$(Get-Process)') }
}
It "rejects: <MaliciousInput>" -TestCases @(
    $SecurityConfig.MaliciousInputPatterns | ForEach-Object { @{ MaliciousInput = $_ } }
) { ... }

# RIGHT - built at discovery time, generates one test per pattern
BeforeDiscovery {
    $MaliciousInputPatterns = @("'; DROP TABLE Users; --", '$(Get-Process)')
}
It "rejects: <MaliciousInput>" -ForEach $MaliciousInputPatterns.ForEach({
    @{ MaliciousInput = $_ }
}) { ... }
```

If the source list is genuinely empty (`@()` rather than `$null`), Pester 6 **fails discovery** with
`Run.FailOnNullOrEmptyForEach` rather than running zero tests. For a security suite that is exactly
the behavior you want - do not disable it, and do not reach for `-AllowNullOrEmptyForEach` here.

Verify the suite generates the test count you expect:

```powershell
$config = New-PesterConfiguration
$config.Run.Path = './Tests/Security'
$config.Run.SkipRun = $true
$config.Run.PassThru = $true
$discovered = Invoke-Pester -Configuration $config
"Discovered $($discovered.TotalCount) security tests"
```

### Quote attack patterns correctly

Use **single quotes** for patterns containing `$`. In the original template
`"$(Get-Process)"` was a double-quoted string, so PowerShell expanded it at parse time and the test
fed the _output of `Get-Process`_ to the function instead of the literal injection string.

```powershell
'$(Get-Process)'          # literal - what you want to test
"$(Get-Process)"          # expanded at parse time - tests nothing useful
```

### Escape values used as regex

`Should-MatchString` / `Should-NotMatchString` take a regex. Credentials and connection strings
contain `.`, `$`, `(`, and `\`, which are metacharacters. Escape them:

```powershell
$output | Should-NotMatchString ([regex]::Escape($password))
```

An unescaped `.` matches any character, which usually makes the assertion _more_ likely to match and
therefore _less_ likely to catch a leak - a false sense of security.

### Assert the action did not happen

For authorization tests, `Should-NotInvoke` is stronger evidence than `Should-Throw`. A function can
throw _after_ performing the privileged action:

```powershell
Mock Invoke-PrivilegedAction { }
{ Function-Name -RequiredRole 'Administrator' } | Should-Throw
Should-NotInvoke Invoke-PrivilegedAction
```

### Do not put the only assertions inside a `catch`

A `try`/`catch` whose assertions live only in the `catch` block passes silently when the code does
**not** throw. Capture the error and assert it was thrown, or use `Should-Throw`.

## Security Test Guidelines

### Input Validation Testing

- Test all forms of malicious input
- Validate parameter length limits
- Test encoding and special characters
- Verify path traversal prevention
- Test command injection attempts

### Credential Security Testing

- Verify credentials are never exposed in logs
- Test SecureString handling
- Validate authentication mechanisms
- Test credential caching security
- Verify secure credential transmission

### Access Control Testing

- Test role-based access control
- Validate file system permissions
- Test session management
- Verify authorization enforcement
- Test privilege escalation prevention

### Data Protection Testing

- Test encryption at rest and in transit
- Validate secure data handling
- Test password hashing algorithms
- Verify secure deletion methods
- Test data anonymization features

### Compliance and Audit Testing

- Verify security event logging
- Test data retention compliance
- Validate audit trail integrity
- Test compliance data export
- Verify regulatory requirement adherence

### Error Handling Security

- Ensure no sensitive data in error messages
- Test error information disclosure
- Validate secure error logging
- Test error handling under attack conditions
- Verify graceful failure modes
