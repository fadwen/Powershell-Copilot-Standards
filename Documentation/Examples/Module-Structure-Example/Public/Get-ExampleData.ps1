function Get-ExampleData {
    # The full help for this command lives in docs/ModuleExample/Get-ExampleData.md and
    # ships compiled as en-US/ModuleExample-Help.xml. See
    # .github/instructions/platyps.instructions.md

    <#
    .EXTERNALHELP ModuleExample-Help.xml
    .SYNOPSIS
        Retrieves service status for one or more services.
    #>

    [CmdletBinding()]
    [OutputType('ExampleServiceResult')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ServiceName,

        [Parameter()]
        [ValidateSet('Development', 'Test', 'Production')]
        [string]$Environment = 'Development',

        [Parameter()]
        [guid]$CorrelationId = [guid]::NewGuid()
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand.Name) - CorrelationId: $CorrelationId"
        $session = Connect-ExampleService -Environment $Environment -CorrelationId $CorrelationId
        $failureCount = 0
    }

    process {
        foreach ($name in $ServiceName) {
            try {
                $result = [ExampleServiceResult]::new($name, $Environment, $CorrelationId)

                # The one fallible call in the loop. Keeping it in a helper is what
                # makes the catch below reachable - and therefore testable.
                $result.Status = Get-ExampleServiceStatus -ServiceName $name -Session $session

                $result
            }
            catch {
                # $_ in the catch block, per the standards - not $Error[0]
                $failureCount++
                Write-Error "Failed to query '$name': $($_.Exception.Message) (CorrelationId: $CorrelationId)"
                continue
            }
        }
    }

    end {
        Write-Verbose "Completed with $failureCount failure(s) - CorrelationId: $CorrelationId"
    }
}
