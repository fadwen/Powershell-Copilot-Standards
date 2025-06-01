@{
    # Module Behavior Settings
    ModuleSettings = @{
        EnableVerboseLogging = $true
        RequireCorrelationIds = $true
        EnforceParameterValidation = $true
        EnablePerformanceMonitoring = $true
    }

    # Environment-Specific Configuration
    Environments = @{
        Development = @{
            LogLevel = 'Verbose'
            TimeoutSeconds = 30
            RetryCount = 3
            PerformanceThreshold = 5000
            AuditLevel = 'Full'
            SecurityValidation = 'Relaxed'
        }

        Testing = @{
            LogLevel = 'Standard'
            TimeoutSeconds = 20
            RetryCount = 2
            PerformanceThreshold = 3000
            AuditLevel = 'Standard'
            SecurityValidation = 'Standard'
        }

        Production = @{
            LogLevel = 'Minimal'
            TimeoutSeconds = 10
            RetryCount = 1
            PerformanceThreshold = 1000
            AuditLevel = 'Required'
            SecurityValidation = 'Strict'
        }
    }

    # Security Configuration
    Security = @{
        RequireEncryption = $true
        AllowBasicAuth = $false  # Expert feedback: Basic auth not recommended
        RequireSignedCertificates = $true
        EnforceCredentialValidation = $true
        AuditAllOperations = $true

        # Approved authentication methods
        AuthenticationMethods = @('Kerberos', 'Certificate', 'Negotiate')

        # Security scanning patterns
        ProhibitedPatterns = @(
            'password\s*[:=]\s*["\x27]\w{3,}["\x27]',
            'api[_-]?key\s*[:=]\s*["\x27]\w{10,}["\x27]',
            'ConvertTo-SecureString.*-AsPlainText.*-Force'
        )
    }

    # Performance Optimization Settings
    Performance = @{
        # String operation thresholds (expert feedback integration)
        StringConcatenationThreshold = 100  # Use StringBuilder above this
        ArrayAppendThreshold = 50           # Use ArrayList above this

        # Memory management
        MaxMemoryUsageMB = 512
        EnableGarbageCollection = $true

        # Pipeline optimization
        PreferPipelineOperations = $true
        BatchSizeLimit = 1000
    }

    # Compliance Framework Integration
    Compliance = @{
        SOX = @{
            RequireAuditTrails = $true
            RequireApprovalWorkflow = $true
            MandatoryFields = @('CorrelationId', 'UserName', 'Timestamp', 'Operation')
        }

        GDPR = @{
            EnableDataMinimization = $true
            RequireConsentTracking = $true
            AutoDeleteExpiredData = $true
            DataRetentionDays = 2555  # 7 years
        }

        HIPAA = @{
            RequireEncryption = $true
            EnableAccessLogging = $true
            RequireRoleBasedAccess = $true
            AuditAccessAttempts = $true
        }
    }

    # Error Handling Configuration
    ErrorHandling = @{
        # Expert feedback: Use Write-Error -ErrorAction Stop instead of bare throw
        UseWriteErrorForTermination = $true

        # Correlation ID requirements
        RequireCorrelationIds = $true

        # Error escalation thresholds
        EscalationLevels = @{
            Low = @{ ThresholdCount = 10; EscalationTimeMinutes = 60 }
            Medium = @{ ThresholdCount = 5; EscalationTimeMinutes = 30 }
            High = @{ ThresholdCount = 2; EscalationTimeMinutes = 15 }
            Critical = @{ ThresholdCount = 1; EscalationTimeMinutes = 5 }
        }
    }

    # Quality Standards Integration
    QualityStandards = @{
        # PSScriptAnalyzer settings
        EnableStrictMode = $true
        RequireApprovedVerbs = $true
        MaxComplexityScore = 15
        MinimumTestCoverage = 80

        # Documentation requirements
        RequireCommentBasedHelp = $true
        RequireExamples = $true
        RequireParameterDocumentation = $true

        # Parameter validation standards
        ValidateParametersBeforeDownstreamUsage = $true  # Expert feedback Part 2
        TrimStringParametersAutomatically = $true
    }

    # Integration Endpoints
    Integration = @{
        LoggingService = @{
            Endpoint = 'https://logs.entravantage.com/api/v1/logs'
            RequireAuthentication = $true
            TimeoutSeconds = 30
        }

        SecurityService = @{
            Endpoint = 'https://security.entravantage.com/api/v1/audit'
            RequireAuthentication = $true
            TimeoutSeconds = 15
        }

        ComplianceService = @{
            Endpoint = 'https://compliance.entravantage.com/api/v1/events'
            RequireAuthentication = $true
            TimeoutSeconds = 45
        }
    }
}