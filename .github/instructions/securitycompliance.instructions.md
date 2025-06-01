---
mode: 'agent'
applyTo: "**/*.ps1,**/*.psm1,**/Security/**/*.ps1"
tools: ['codebase', 'githubRepo']
description: 'Implements comprehensive security controls and compliance frameworks for PowerShell solutions'
---

# PowerShell Security and Compliance Implementation

Implement robust security controls and compliance frameworks for PowerShell solutions that ensure enterprise-grade security, regulatory compliance, threat mitigation, and comprehensive audit capabilities. Apply security-by-design principles throughout development.

## Security Assessment and Implementation

### Security Requirements Analysis
Evaluate and implement security controls based on:

#### Security Classification
- **Public**: No restrictions, publicly accessible code
- **Internal**: Internal use only, basic access controls required
- **Confidential**: Sensitive data, enhanced protection required
- **Restricted**: Highly sensitive, strict access controls mandatory
- **Top Secret**: Maximum security, compartmentalized access

#### Threat Model Assessment
Identify and mitigate threats using STRIDE methodology:
- **Spoofing**: Identity verification and authentication controls
- **Tampering**: Data integrity and code signing requirements
- **Repudiation**: Audit logging and non-repudiation controls
- **Information Disclosure**: Data protection and access controls
- **Denial of Service**: Availability and resilience measures
- **Elevation of Privilege**: Authorization and privilege management

### Input Validation and Sanitization
Implement comprehensive input validation for all user inputs:

```powershell
function Protect-UserInput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InputString,
        [ValidateSet('ComputerName', 'FileName', 'UserName', 'FilePath', 'EmailAddress')]
        [string]$InputType = 'General',
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    # Log security validation attempt
    Write-SecurityLog -SecurityEventType 'DataValidation' -Message "Input validation requested" -Outcome 'Attempt' -CorrelationId $CorrelationId -SecurityContext @{
        InputType = $InputType
        InputLength = $InputString.Length
    }

    # Length validation
    if ($InputString.Length -gt 1000) {
        throw [SecurityException]::new("Input exceeds maximum length of 1000 characters", 'InputValidation', 'Length-Check')
    }

    # Type-specific validation patterns
    switch ($InputType) {
        'ComputerName' {
            if ($InputString -notmatch '^[a-zA-Z0-9\-\.]+$') {
                throw [SecurityException]::new("Invalid computer name format", 'InputValidation', 'Format-Check')
            }
        }
        'FileName' {
            $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
            foreach ($char in $invalidChars) {
                if ($InputString.Contains($char)) {
                    throw [SecurityException]::new("Invalid file name character: $char", 'InputValidation', 'Character-Check')
                }
            }
        }
        'FilePath' {
            # Prevent path traversal attacks
            $normalizedPath = [System.IO.Path]::GetFullPath($InputString)
            if ($normalizedPath.Contains('..') -or $normalizedPath.Contains('~')) {
                throw [SecurityException]::new("Path traversal attempt detected", 'InputValidation', 'Path-Traversal')
            }
        }
        'EmailAddress' {
            if ($InputString -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                throw [SecurityException]::new("Invalid email address format", 'InputValidation', 'Email-Format')
            }
        }
    }

    # Check for common injection patterns
    $dangerousPatterns = @(
        ';',           # Command separator
        '&',           # Command separator
        '|',           # Pipe operator
        '<',           # Redirect
        '>',           # Redirect
        '`',           # Backtick execution
        '$(',          # Subexpression
        'Invoke-',     # Dangerous cmdlets
        'iex',         # Invoke-Expression alias
        'Remove-',     # Destructive operations
        'Format-'      # Format string attacks
    )

    foreach ($pattern in $dangerousPatterns) {
        if ($InputString -like "*$pattern*") {
            Write-SecurityLog -SecurityEventType 'SecurityViolation' -Message "Dangerous pattern detected in input" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
                Pattern = $pattern
                InputSample = $InputString.Substring(0, [Math]::Min(50, $InputString.Length))
            } -RiskLevel 'High'

            throw [SecurityException]::new("Input contains potentially dangerous pattern: $pattern", 'InputValidation', 'Injection-Prevention')
        }
    }

    Write-SecurityLog -SecurityEventType 'DataValidation' -Message "Input validation successful" -Outcome 'Success' -CorrelationId $CorrelationId
    return $InputString.Trim()
}
```

### Credential and Secret Management
Implement secure credential handling using SecretManagement:

```powershell
function Get-SecureCredential {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [string]$VaultName,
        [string]$Purpose = 'General',
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    try {
        Write-SecurityLog -SecurityEventType 'Authentication' -Message "Credential retrieval requested" -Outcome 'Attempt' -CorrelationId $CorrelationId -SecurityContext @{
            CredentialName = $Name
            VaultName = $VaultName
            Purpose = $Purpose
        }

        # Rate limiting check to prevent brute force
        $rateLimitResult = Test-CredentialAccessRateLimit -CredentialName $Name -CorrelationId $CorrelationId
        if (-not $rateLimitResult.Allowed) {
            Write-SecurityLog -SecurityEventType 'SecurityViolation' -Message "Credential access rate limit exceeded" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
                CredentialName = $Name
                AttemptsInLastHour = $rateLimitResult.RecentAttempts
            } -RiskLevel 'High'

            throw [SecurityException]::new("Credential access rate limit exceeded for: $Name", 'CredentialManagement', 'Rate-Limiting')
        }

        # Attempt to retrieve from SecretManagement vault
        $credential = Get-Secret -Name $Name -Vault $VaultName -AsPlainText:$false -ErrorAction Stop

        if ($credential) {
            Write-SecurityLog -SecurityEventType 'Authentication' -Message "Credential retrieved successfully" -Outcome 'Success' -CorrelationId $CorrelationId -SecurityContext @{
                CredentialName = $Name
                VaultName = $VaultName
            }

            return $credential
        }

    }
    catch {
        Write-SecurityLog -SecurityEventType 'Authentication' -Message "Credential retrieval failed" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
            CredentialName = $Name
            Error = $_.Exception.Message
        } -RiskLevel 'Medium'

        # Fallback to interactive prompt with security warning
        Write-Warning "Credential not found in secure vault. Interactive prompt required."
        return Get-Credential -Message "Enter credentials for: $Name"
    }
}

function Set-SecureCredential {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        [string]$VaultName,
        [ValidateSet('Low', 'Medium', 'High', 'Critical')]
        [string]$SecurityLevel = 'Medium',
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    try {
        # Validate credential strength
        $credentialValidation = Test-CredentialSecurity -Credential $Credential -SecurityLevel $SecurityLevel

        if (-not $credentialValidation.IsValid) {
            throw [SecurityException]::new("Credential does not meet security requirements: $($credentialValidation.Errors -join '; ')", 'CredentialManagement', 'Security-Validation')
        }

        # Store credential with metadata
        $metadata = @{
            StoredBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            StoredAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            SecurityLevel = $SecurityLevel
            CorrelationId = $CorrelationId
        }

        Set-Secret -Name $Name -Secret $Credential -Vault $VaultName -Metadata $metadata

        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "Credential stored successfully" -Outcome 'Success' -CorrelationId $CorrelationId -SecurityContext @{
            CredentialName = $Name
            SecurityLevel = $SecurityLevel
        }

    }
    catch {
        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "Credential storage failed" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
            CredentialName = $Name
            Error = $_.Exception.Message
        } -RiskLevel 'High'
        throw
    }
}
```

## Compliance Framework Implementation

### SOX (Sarbanes-Oxley) Compliance
Implement controls for financial data processing:

```powershell
function Invoke-SOXCompliance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        [hashtable]$FinancialData = @{},
        [string]$BusinessJustification,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    try {
        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "SOX compliance validation initiated" -Outcome 'Attempt' -CorrelationId $CorrelationId -SecurityContext @{
            Operation = $Operation
            BusinessJustification = $BusinessJustification
            ComplianceFramework = 'SOX'
        }

        $complianceResults = @{
            Operation = $Operation
            ComplianceStatus = 'Compliant'
            ControlsValidated = @()
            DeficienciesFound = @()
            AuditTrail = @()
        }

        # Validate management approval for financial operations
        $operationsRequiringApproval = @('FinancialDataModification', 'ReportGeneration', 'DataDeletion')
        if ($Operation -in $operationsRequiringApproval) {
            $approvalValidation = Test-ManagementApproval -Operation $Operation -BusinessJustification $BusinessJustification

            if (-not $approvalValidation.Approved) {
                $complianceResults.DeficienciesFound += 'Management approval required but not obtained'
                $complianceResults.ComplianceStatus = 'Non-Compliant'
            } else {
                $complianceResults.ControlsValidated += 'Management Approval: Verified'
            }
        }

        # Validate data integrity controls
        if ($FinancialData.Count -gt 0) {
            $integrityValidation = Test-DataIntegrityControls -Data $FinancialData

            if (-not $integrityValidation.IntegrityVerified) {
                $complianceResults.DeficienciesFound += 'Data integrity validation failed'
                $complianceResults.ComplianceStatus = 'Non-Compliant'
            }
        }

        # Ensure audit trail requirements
        $auditTrailValidation = Test-AuditTrailRequirements -Operation $Operation
        if (-not $auditTrailValidation.Compliant) {
            $complianceResults.DeficienciesFound += $auditTrailValidation.Deficiencies
            $complianceResults.ComplianceStatus = 'Non-Compliant'
        }

        # Generate compliance report
        $complianceReport = @{
            ComplianceFramework = 'SOX'
            AssessmentDate = Get-Date
            CorrelationId = $CorrelationId
            Operation = $Operation
            OverallStatus = $complianceResults.ComplianceStatus
            ControlsValidated = $complianceResults.ControlsValidated
            DeficienciesFound = $complianceResults.DeficienciesFound
        }

        # Store compliance record
        Set-ComplianceRecord -Framework 'SOX' -Report $complianceReport

        return $complianceReport
    }
    catch {
        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "SOX compliance validation failed" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
            Operation = $Operation
            Error = $_.Exception.Message
        } -RiskLevel 'Critical'
        throw
    }
}
```

### GDPR (General Data Protection Regulation) Compliance
Implement data protection controls for personal data:

```powershell
function Invoke-GDPRCompliance {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Collection', 'Processing', 'Storage', 'Transfer', 'Deletion', 'Access')]
        [string]$DataOperation,
        [hashtable]$PersonalData = @{},
        [ValidateSet('Consent', 'Contract', 'LegalObligation', 'VitalInterests', 'PublicTask', 'LegitimateInterests')]
        [string]$LegalBasis,
        [string]$DataSubjectId,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    try {
        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "GDPR compliance validation initiated" -Outcome 'Attempt' -CorrelationId $CorrelationId -SecurityContext @{
            DataOperation = $DataOperation
            LegalBasis = $LegalBasis
            ComplianceFramework = 'GDPR'
        }

        $gdprCompliance = @{
            Operation = $DataOperation
            ComplianceStatus = 'Compliant'
            LegalBasisValidated = $false
            ConsentVerified = $false
            DataMinimizationCompliant = $false
            SecurityMeasuresValid = $false
            ViolationsFound = @()
        }

        # Article 6: Legal basis validation
        $legalBasisValidation = Test-GDPRLegalBasis -Operation $DataOperation -LegalBasis $LegalBasis -DataSubjectId $DataSubjectId
        if ($legalBasisValidation.Valid) {
            $gdprCompliance.LegalBasisValidated = $true
        } else {
            $gdprCompliance.ViolationsFound += "Invalid legal basis: $($legalBasisValidation.Reason)"
            $gdprCompliance.ComplianceStatus = 'Non-Compliant'
        }

        # Article 7: Consent validation (if consent is the legal basis)
        if ($LegalBasis -eq 'Consent') {
            $consentValidation = Test-GDPRConsent -DataSubjectId $DataSubjectId -DataOperation $DataOperation
            if ($consentValidation.Valid -and $consentValidation.Current) {
                $gdprCompliance.ConsentVerified = $true
            } else {
                $gdprCompliance.ViolationsFound += "Invalid or expired consent"
                $gdprCompliance.ComplianceStatus = 'Non-Compliant'
            }
        }

        # Article 5: Data minimization principle
        if ($PersonalData.Count -gt 0) {
            $minimizationValidation = Test-DataMinimization -PersonalData $PersonalData -DataOperation $DataOperation
            if ($minimizationValidation.Compliant) {
                $gdprCompliance.DataMinimizationCompliant = $true
            } else {
                $gdprCompliance.ViolationsFound += $minimizationValidation.Violations
                $gdprCompliance.ComplianceStatus = 'Non-Compliant'
            }
        }

        # Article 32: Security of processing
        $securityValidation = Test-GDPRSecurityMeasures -DataOperation $DataOperation -PersonalData $PersonalData
        if ($securityValidation.Adequate) {
            $gdprCompliance.SecurityMeasuresValid = $true
        } else {
            $gdprCompliance.ViolationsFound += $securityValidation.Deficiencies
        }

        # Generate GDPR compliance report
        $gdprReport = @{
            ComplianceFramework = 'GDPR'
            AssessmentDate = Get-Date
            CorrelationId = $CorrelationId
            DataOperation = $DataOperation
            DataSubjectId = $DataSubjectId
            LegalBasis = $LegalBasis
            OverallStatus = $gdprCompliance.ComplianceStatus
            ViolationsFound = $gdprCompliance.ViolationsFound
        }

        # Record processing activity (Article 30)
        Set-GDPRProcessingRecord -Record $gdprReport

        return $gdprReport
    }
    catch {
        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "GDPR compliance validation failed" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
            DataOperation = $DataOperation
            Error = $_.Exception.Message
        } -RiskLevel 'Critical'
        throw
    }
}
```

### HIPAA Compliance (Healthcare)
Implement healthcare data protection controls:

```powershell
function Invoke-HIPAACompliance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataOperation,
        [hashtable]$HealthInformation = @{},
        [string]$CoveredEntity,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    $hipaaCompliance = @{
        Operation = $DataOperation
        ComplianceStatus = 'Compliant'
        SafeguardsImplemented = @()
        Violations = @()
    }

    # Administrative Safeguards (§164.308)
    $adminSafeguards = Test-HIPAAAdministrativeSafeguards -Operation $DataOperation
    if ($adminSafeguards.Compliant) {
        $hipaaCompliance.SafeguardsImplemented += 'Administrative Safeguards: Compliant'
    } else {
        $hipaaCompliance.Violations += $adminSafeguards.Violations
    }

    # Physical Safeguards (§164.310)
    $physicalSafeguards = Test-HIPAAPhysicalSafeguards -Operation $DataOperation
    if ($physicalSafeguards.Compliant) {
        $hipaaCompliance.SafeguardsImplemented += 'Physical Safeguards: Compliant'
    } else {
        $hipaaCompliance.Violations += $physicalSafeguards.Violations
    }

    # Technical Safeguards (§164.312)
    $technicalSafeguards = Test-HIPAATechnicalSafeguards -HealthInformation $HealthInformation
    if ($technicalSafeguards.Compliant) {
        $hipaaCompliance.SafeguardsImplemented += 'Technical Safeguards: Compliant'
    } else {
        $hipaaCompliance.Violations += $technicalSafeguards.Violations
    }

    if ($hipaaCompliance.Violations.Count -gt 0) {
        $hipaaCompliance.ComplianceStatus = 'Non-Compliant'
    }

    return $hipaaCompliance
}
```

## Code Signing and Certificate Management

### Automated Code Signing Implementation
```powershell
function Invoke-CodeSigning {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]$FilePath,
        [string]$Environment = 'Development',
        [string]$CertificateThumbprint,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    begin {
        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "Code signing operation initiated" -Outcome 'Attempt' -CorrelationId $CorrelationId -SecurityContext @{
            Environment = $Environment
            FileCount = @($FilePath).Count
        }

        # Get signing configuration
        $signingConfig = Get-CodeSigningConfiguration -Environment $Environment
        if (-not $signingConfig) {
            throw [SecurityException]::new("Code signing not configured for environment: $Environment", 'CodeSigning', 'Configuration')
        }

        # Override certificate if specified
        if ($CertificateThumbprint) {
            $signingConfig.CertificateThumbprint = $CertificateThumbprint
        }

        # Validate certificate
        $certificate = Get-Item "Cert:\CurrentUser\My\$($signingConfig.CertificateThumbprint)" -ErrorAction SilentlyContinue
        if (-not $certificate) {
            throw [SecurityException]::new("Code signing certificate not found: $($signingConfig.CertificateThumbprint)", 'CodeSigning', 'Certificate-Access')
        }

        $signedFiles = @()
        $failedFiles = @()
    }

    process {
        foreach ($file in $FilePath) {
            try {
                # Validate file exists and is appropriate type
                if (-not (Test-Path $file)) {
                    throw "File not found: $file"
                }

                $fileInfo = Get-Item $file
                $allowedExtensions = @('.ps1', '.psm1', '.psd1', '.ps1xml')
                if ($fileInfo.Extension -notin $allowedExtensions) {
                    throw "File type not approved for signing: $($fileInfo.Extension)"
                }

                # Perform security scan before signing
                $scanResult = Invoke-SecurityScan -FilePath $file
                if ($scanResult.HighRiskIssues -gt 0) {
                    throw "Security scan failed: High risk issues found"
                }

                # Sign the file
                $signature = Set-AuthenticodeSignature -FilePath $file -Certificate $certificate -TimestampServer $signingConfig.TimestampServer

                if ($signature.Status -eq 'Valid') {
                    $signedFiles += @{
                        FilePath = $file
                        SignatureStatus = $signature.Status
                        SignerCertificate = $signature.SignerCertificate.Thumbprint
                        SignedAt = Get-Date
                    }

                    Write-SecurityLog -SecurityEventType 'DataAccess' -Message "File signed successfully" -Outcome 'Success' -CorrelationId $CorrelationId -SecurityContext @{
                        FilePath = $file
                        CertificateThumbprint = $certificate.Thumbprint
                    }
                }
            }
            catch {
                $failedFiles += @{
                    FilePath = $file
                    Error = $_.Exception.Message
                    FailedAt = Get-Date
                }

                Write-SecurityLog -SecurityEventType 'DataAccess' -Message "File signing failed" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
                    FilePath = $file
                    Error = $_.Exception.Message
                } -RiskLevel 'Medium'
            }
        }
    }

    end {
        $summary = @{
            TotalFiles = @($FilePath).Count
            SignedFiles = $signedFiles.Count
            FailedFiles = $failedFiles.Count
            SignedFileDetails = $signedFiles
            FailedFileDetails = $failedFiles
            CorrelationId = $CorrelationId
        }

        Write-SecurityLog -SecurityEventType 'DataAccess' -Message "Code signing operation completed" -Outcome 'Success' -CorrelationId $CorrelationId -SecurityContext $summary

        return $summary
    }
}
```

### Security Scanning Integration
Implement automated security scanning:

```powershell
function Invoke-SecurityScan {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [string]$CorrelationId = [System.Guid]::NewGuid().ToString()
    )

    $scanResults = @{
        FilePath = $FilePath
        ScanDate = Get-Date
        TotalIssues = 0
        CriticalIssues = 0
        HighRiskIssues = 0
        MediumRiskIssues = 0
        LowRiskIssues = 0
        SecurityFindings = @()
        OverallRisk = 'Low'
    }

    try {
        Write-SecurityLog -SecurityEventType 'SecurityViolation' -Message "Security scan initiated" -Outcome 'Attempt' -CorrelationId $CorrelationId -SecurityContext @{
            FilePath = $FilePath
            ScanType = 'Comprehensive'
        }

        $fileContent = Get-Content -Path $FilePath -Raw

        # Credential leak detection
        $credentialPatterns = @(
            @{ Pattern = '(?i)(password|pwd|pass)\s*[:=]\s*["\']?[^"\'\s]{8,}'; Risk = 'Critical'; Description = 'Potential hardcoded password' }
            @{ Pattern = '(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?[a-zA-Z0-9]{20,}'; Risk = 'Critical'; Description = 'Potential API key exposure' }
            @{ Pattern = '(?i)(secret|token)\s*[:=]\s*["\']?[a-zA-Z0-9]{16,}'; Risk = 'High'; Description = 'Potential secret or token exposure' }
            @{ Pattern = 'ConvertTo-SecureString\s+-String\s+["\'][^"\']+["\']'; Risk = 'High'; Description = 'Hardcoded secure string conversion' }
        )

        foreach ($patternInfo in $credentialPatterns) {
            if ($fileContent -match $patternInfo.Pattern) {
                $finding = @{
                    Type = 'CredentialLeak'
                    Risk = $patternInfo.Risk
                    Description = $patternInfo.Description
                    Pattern = $patternInfo.Pattern
                    LineNumber = ($fileContent.Substring(0, $fileContent.IndexOf($Matches[0])).Split("`n").Count)
                }

                $scanResults.SecurityFindings += $finding

                switch ($patternInfo.Risk) {
                    'Critical' { $scanResults.CriticalIssues++ }
                    'High' { $scanResults.HighRiskIssues++ }
                    'Medium' { $scanResults.MediumRiskIssues++ }
                    'Low' { $scanResults.LowRiskIssues++ }
                }
            }
        }

        # Command injection detection
        $injectionPatterns = @(
            @{ Pattern = 'Invoke-Expression'; Risk = 'High'; Description = 'Use of Invoke-Expression detected' }
            @{ Pattern = 'iex\s'; Risk = 'High'; Description = 'Use of iex alias detected' }
            @{ Pattern = 'Add-Type.*-TypeDefinition'; Risk = 'Medium'; Description = 'Dynamic type compilation detected' }
        )

        foreach ($patternInfo in $injectionPatterns) {
            if ($fileContent -match $patternInfo.Pattern) {
                $finding = @{
                    Type = 'CodeInjection'
                    Risk = $patternInfo.Risk
                    Description = $patternInfo.Description
                    Pattern = $patternInfo.Pattern
                }

                $scanResults.SecurityFindings += $finding

                switch ($patternInfo.Risk) {
                    'High' { $scanResults.HighRiskIssues++ }
                    'Medium' { $scanResults.MediumRiskIssues++ }
                    'Low' { $scanResults.LowRiskIssues++ }
                }
            }
        }

        # Calculate overall risk
        if ($scanResults.CriticalIssues -gt 0) {
            $scanResults.OverallRisk = 'Critical'
        } elseif ($scanResults.HighRiskIssues -gt 0) {
            $scanResults.OverallRisk = 'High'
        } elseif ($scanResults.MediumRiskIssues -gt 0) {
            $scanResults.OverallRisk = 'Medium'
        }

        $scanResults.TotalIssues = $scanResults.CriticalIssues + $scanResults.HighRiskIssues + $scanResults.MediumRiskIssues + $scanResults.LowRiskIssues

        Write-SecurityLog -SecurityEventType 'SecurityViolation' -Message "Security scan completed" -Outcome 'Success' -CorrelationId $CorrelationId -SecurityContext @{
            FilePath = $FilePath
            TotalIssues = $scanResults.TotalIssues
            OverallRisk = $scanResults.OverallRisk
            CriticalIssues = $scanResults.CriticalIssues
        }

        return $scanResults
    }
    catch {
        Write-SecurityLog -SecurityEventType 'SecurityViolation' -Message "Security scan failed" -Outcome 'Failure' -CorrelationId $CorrelationId -SecurityContext @{
            FilePath = $FilePath
            Error = $_.Exception.Message
        } -RiskLevel 'Medium'
        throw
    }
}
```

## Implementation Requirements

### Security Integration Checklist
When implementing security and compliance controls:

#### Required Security Components
- [ ] **Input validation** for all user-provided data with type-specific patterns
- [ ] **Credential management** using SecretManagement with secure vault integration
- [ ] **Security logging** with correlation IDs and appropriate detail levels
- [ ] **Code signing** infrastructure with certificate validation and timestamp services
- [ ] **Security scanning** integration for credential leaks and injection vulnerabilities
- [ ] **Access controls** implementing principle of least privilege
- [ ] **Audit trail** maintenance for compliance and forensic requirements

#### Compliance Framework Integration
- [ ] **SOX compliance** for financial data operations with management approval workflows
- [ ] **GDPR compliance** for personal data processing with consent management
- [ ] **HIPAA compliance** for healthcare information with comprehensive safeguards
- [ ] **PCI DSS compliance** for payment card data (if applicable)
- [ ] **Data retention** policies and automated enforcement
- [ ] **Right to erasure** implementation for GDPR Article 17 compliance

#### Enterprise Integration Points
- [ ] Integration with enterprise identity management systems
- [ ] Connection to centralized logging and SIEM platforms
- [ ] Compliance reporting automation and dashboard integration
- [ ] Security incident response procedures and escalation
- [ ] Regular security assessment and penetration testing integration
- [ ] Security awareness training integration and tracking

### Troubleshooting Documentation Integration
All security and compliance implementations must include:

- **Security troubleshooting guides** in `./Troubleshooting/Security/` folder
- **Compliance procedures** in `./Troubleshooting/Compliance/` folder
- **Incident response playbooks** in `./Troubleshooting/Incident-Response/` folder
- **Configuration guides** with step-by-step security setup procedures
- **Error resolution** documentation with correlation ID usage examples

Generate comprehensive security and compliance implementations that provide enterprise-grade protection while maintaining usability and performance. Ensure all controls integrate with established PowerShell development standards and maintain proper documentation in the `./Troubleshooting/` folder structure for consistent organizational reference.