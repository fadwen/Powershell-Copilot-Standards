# Security Test Template

## Standard Security Test Structure

Use this template for validating security controls and input sanitization:

```powershell
#Requires -Module Pester

BeforeAll {
    # Import module under test
    $ModulePath = Join-Path $PSScriptRoot '..\..\ModuleName.psd1'
    Import-Module $ModulePath -Force

    # Security test configuration
    $SecurityConfig = @{
        MaliciousInputPatterns = @(
            "'; DROP TABLE Users; --"
            "../../../etc/passwd"
            "<script>alert('xss')</script>"
            "$(Get-Process)"
            "Invoke-Expression 'malicious code'"
            "& cmd.exe /c dir"
            "`$(Get-Content secrets.txt)"
        )

        PathTraversalPatterns = @(
            "..\..\Windows\System32\config"
            "../../../../etc/shadow"
            "..\..\..\secrets\passwords.txt"
            "C:\Windows\System32\SAM"
        )

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
        It "Should reject malicious input patterns: <MaliciousInput>" -TestCases @(
            $SecurityConfig.MaliciousInputPatterns | ForEach-Object {
                @{ MaliciousInput = $_; ExpectedError = '*invalid characters*' }
            }
        ) {
            param($MaliciousInput, $ExpectedError)

            { Function-Name -ParameterName $MaliciousInput } | Should -Throw $ExpectedError
        }

        It "Should sanitize file paths against traversal: <UnsafePath>" -TestCases @(
            $SecurityConfig.PathTraversalPatterns | ForEach-Object {
                @{ UnsafePath = $_; ExpectedError = '*invalid path*' }
            }
        ) {
            param($UnsafePath, $ExpectedError)

            { Function-Name -FilePath $UnsafePath } | Should -Throw $ExpectedError
        }

        It "Should validate parameter length limits" {
            $oversizedInput = "x" * 10000  # 10KB string

            { Function-Name -ParameterName $oversizedInput } | Should -Throw "*exceeds maximum length*"
        }

        It "Should reject null and empty inputs appropriately" {
            # Test null input
            { Function-Name -ParameterName $null } | Should -Throw "*cannot be null*"

            # Test empty string
            { Function-Name -ParameterName "" } | Should -Throw "*cannot be empty*"

            # Test whitespace-only input
            { Function-Name -ParameterName "   " } | Should -Throw "*cannot be empty*"
        }

        It "Should validate email format if email parameter exists" {
            $invalidEmails = @(
                "notanemail"
                "@domain.com"
                "user@"
                "user..name@domain.com"
                "user@domain"
            )

            foreach ($email in $invalidEmails) {
                { Function-Name -EmailAddress $email } | Should -Throw "*invalid email*"
            }
        }

        It "Should prevent command injection in parameters" {
            $injectionAttempts = @(
                "normalvalue; Remove-Item C:\temp\*"
                "value`$(Get-Process)"
                "value & dir"
                "value | Get-Content secrets.txt"
            )

            foreach ($injection in $injectionAttempts) {
                { Function-Name -ParameterName $injection } | Should -Throw "*invalid characters*"
            }
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

            # Ensure credentials are not exposed anywhere
            $outputText | Should -Not -Match $SecurityConfig.TestCredentials.Valid.Username
            $outputText | Should -Not -Match $SecurityConfig.TestCredentials.Valid.Password
            $outputText | Should -Not -Match "TestPassword123!"
        }

        It "Should handle SecureString parameters securely" {
            $secureString = ConvertTo-SecureString "SecretValue123" -AsPlainText -Force

            # Function should accept SecureString without exposing value
            $result = Function-Name -SecureParameter $secureString -Verbose 4>&1

            # Verify SecureString value is not exposed in verbose output
            $result | Out-String | Should -Not -Match "SecretValue123"
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

            # Valid credentials should work
            { Function-Name -Credential $validCredential } | Should -Not -Throw

            # Invalid credentials should fail gracefully
            { Function-Name -Credential $invalidCredential } | Should -Throw "*authentication*"
        }

        It "Should implement secure credential caching" {
            $testCredential = New-Object PSCredential(
                "cachetest",
                (ConvertTo-SecureString "CachePassword123" -AsPlainText -Force)
            )

            # First call - should cache credential securely
            $firstResult = Function-Name -Credential $testCredential -CacheCredentials

            # Verify credential is cached but not exposed
            $cacheContent = Get-CredentialCache -ErrorAction SilentlyContinue
            if ($cacheContent) {
                $cacheContent | Out-String | Should -Not -Match "CachePassword123"
                $cacheContent | Out-String | Should -Not -Match "cachetest"
            }
        }
    }

    Context "Access Control and Authorization" {
        It "Should enforce role-based access control" {
            # Test with user role
            Mock Get-CurrentUserRole { return 'User' }
            { Function-Name -RequiredRole 'Administrator' } | Should -Throw "*insufficient privileges*"

            # Test with admin role
            Mock Get-CurrentUserRole { return 'Administrator' }
            { Function-Name -RequiredRole 'Administrator' } | Should -Not -Throw
        }

        It "Should validate file system permissions" {
            $restrictedPath = "C:\Windows\System32\config"

            # Should check permissions before attempting access
            { Function-Name -Path $restrictedPath } | Should -Throw "*access denied*"
        }

        It "Should implement session-based security" {
            # Test session validation
            Mock Get-CurrentSession { return $null }
            { Function-Name -RequireValidSession } | Should -Throw "*invalid session*"

            # Test with valid session
            Mock Get-CurrentSession { return @{ Valid = $true; UserId = 'testuser' } }
            { Function-Name -RequireValidSession } | Should -Not -Throw
        }
    }

    Context "Data Protection and Encryption" {
        It "Should encrypt sensitive data at rest" {
            $sensitiveData = "Confidential Information 12345"

            $result = Function-Name -SensitiveData $sensitiveData -EncryptData

            # Verify data is encrypted (not plaintext)
            $result.EncryptedData | Should -Not -Match "Confidential Information"
            $result.EncryptedData | Should -Not -BeNullOrEmpty

            # Verify encryption metadata is present
            $result.EncryptionAlgorithm | Should -Not -BeNullOrEmpty
            $result.IV | Should -Not -BeNullOrEmpty
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

            $result.Success | Should -Be $true
            $result.Encrypted | Should -Be $true
        }

        It "Should securely hash passwords" {
            $password = "UserPassword123!"

            $result = Function-Name -HashPassword $password

            # Verify password is hashed, not stored in plaintext
            $result.HashedPassword | Should -Not -Match "UserPassword123!"
            $result.HashedPassword | Should -Not -BeNullOrEmpty

            # Verify salt is used
            $result.Salt | Should -Not -BeNullOrEmpty

            # Verify hash algorithm is secure
            $result.Algorithm | Should -BeIn @('SHA256', 'SHA512', 'bcrypt', 'scrypt', 'PBKDF2')
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
            $securityLogs | Should -Not -BeNullOrEmpty
            $securityLogs[0].EventType | Should -Match "Security"
            $securityLogs[0].UserId | Should -Be "testuser"
        }

        It "Should implement data retention policies" {
            $testData = @{
                Id = [System.Guid]::NewGuid()
                Data = "Test data for retention"
                RetentionPeriod = [TimeSpan]::FromDays(30)
            }

            # Store data with retention policy
            $result = Function-Name -StoreData $testData

            # Verify retention metadata is set
            $storedData = Get-StoredData -Id $testData.Id
            $storedData.ExpirationDate | Should -BeGreaterThan (Get-Date)
            $storedData.ExpirationDate | Should -BeLessOrEqual (Get-Date).AddDays(30)
        }

        It "Should support compliance data export" {
            # Generate test compliance data
            1..5 | ForEach-Object {
                Function-Name -CreateComplianceRecord -UserId "user$_" -Action "TestAction$_"
            }

            # Export compliance data
            $exportResult = Function-Name -ExportComplianceData -StartDate (Get-Date).AddDays(-1) -EndDate (Get-Date)

            # Verify export contains required fields
            $exportResult | Should -Not -BeNullOrEmpty
            $exportResult.Records | Should -HaveCount 5
            $exportResult.Records[0] | Should -HaveProperty 'UserId'
            $exportResult.Records[0] | Should -HaveProperty 'Action'
            $exportResult.Records[0] | Should -HaveProperty 'Timestamp'
        }
    }

    Context "Error Handling Security" {
        It "Should not expose sensitive information in error messages" {
            $sensitiveConnectionString = "Server=secret.db.com;Database=confidential;User=admin;Password=secret123"

            # Function should fail but not expose connection details
            try {
                Function-Name -ConnectionString $sensitiveConnectionString -ForceError
            }
            catch {
                $_.Exception.Message | Should -Not -Match "secret.db.com"
                $_.Exception.Message | Should -Not -Match "secret123"
                $_.Exception.Message | Should -Not -Match "confidential"
            }
        }

        It "Should implement secure error logging" {
            # Generate an error condition
            try {
                Function-Name -CauseSecurityError -ErrorAction Stop
            }
            catch {
                # Error should be logged securely without exposing sensitive details
                $errorLogs = Get-ErrorLog -Recent 1
                $errorLogs[0].Message | Should -Not -BeNullOrEmpty
                $errorLogs[0].SanitizedForSecurity | Should -Be $true
            }
        }
    }
}
```

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
