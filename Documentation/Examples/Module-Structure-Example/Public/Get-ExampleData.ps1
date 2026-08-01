function Get-ExampleData {
    <#
    .SYNOPSIS
        Retrieves service status for one or more services.

    .DESCRIPTION
        The exported surface of this example module. Demonstrates the patterns the
        standards require:

        - An approved verb, with a descriptive [OutputType] rather than PSCustomObject
        - Pipeline input, so the function composes
        - A correlation ID generated once and carried through every call
        - $_ in the catch block, and per-item failure that does not abort the batch

    .PARAMETER ServiceName
        One or more service names to query. Accepts pipeline input.

    .PARAMETER Environment
        Environment to query. Defaults to Development so the example is safe to run.

    .PARAMETER CorrelationId
        Optional correlation identifier. One is generated when not supplied, which is
        why the parameter carries no ValidateNotNullOrEmpty - it is never empty.

    .EXAMPLE
        PS> Get-ExampleData -ServiceName 'Billing'

        DESCRIPTION: Queries a single service in the default environment.
        OUTPUT: One ExampleServiceResult.
        USE CASE: Ad-hoc check of a single service.

    .EXAMPLE
        PS> 'Billing', 'Identity' | Get-ExampleData -Environment Test

        DESCRIPTION: Queries two services via the pipeline.
        OUTPUT: One ExampleServiceResult per service.
        USE CASE: Batch check where one failure must not stop the rest.

    .OUTPUTS
        ExampleServiceResult. One object per service queried.

    .NOTES
        Author: Jeffrey Stuhr
        Blog: https://www.techbyjeff.net
        LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/

        TROUBLESHOOTING:
        - Connection issues: .\Troubleshooting\Common\Function-Issues.md
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
                Write-Verbose "Querying $name via $($session.Endpoint)"

                $result = [ExampleServiceResult]::new($name, $Environment, $CorrelationId)

                # Stands in for a real query. Production is treated as degraded purely
                # to show a non-uniform result set.
                $result.Status = if ($Environment -eq 'Production') { 'Degraded' } else { 'Healthy' }

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
