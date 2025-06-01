@{
    # Module Configuration
    ModuleName = 'ModuleName'
    Version = '1.0.0'
    
    # Environment Settings
    Environments = @{
        Development = @{
            LogLevel = 'Debug'
            Timeout = 30
            RetryCount = 1
            AuditLevel = 'Basic'
        }
        Testing = @{
            LogLevel = 'Information'
            Timeout = 60
            RetryCount = 2
            AuditLevel = 'Standard'
        }
        Staging = @{
            LogLevel = 'Information'
            Timeout = 120
            RetryCount = 3
            AuditLevel = 'Enhanced'
        }
        Production = @{
            LogLevel = 'Warning'
            Timeout = 300
            RetryCount = 5
            AuditLevel = 'Comprehensive'
        }
    }
    
    # Security Settings
    Security = @{
        RequireCredentials = $false
        EncryptionRequired = $true
        AuditAll = $true
        MaxInputLength = 1000
    }
    
    # Performance Settings
    Performance = @{
        MaxConcurrentOperations = 10
        DefaultTimeout = 300
        EnableCaching = $true
        CacheExpirationMinutes = 15
    }
    
    # Integration Settings
    Integration = @{
        PSFrameworkLogging = $true
        SecretManagement = $true
        EnterpriseMonitoring = $true
    }
}