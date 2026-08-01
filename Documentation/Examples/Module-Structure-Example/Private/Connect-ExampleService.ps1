function Connect-ExampleService {
    <#
    .SYNOPSIS
        Opens a session against the example backing service.

    .DESCRIPTION
        Private helper, not exported by the manifest. Demonstrates the boundary the
        standards draw between internal and public surface: callers depend on
        Get-ExampleData, so this can change shape without a breaking release.

        Returns a session descriptor the public function passes back in. There is no
        real service behind it; the sleep stands in for connection latency.

    .PARAMETER Environment
        Target environment for the connection.

    .PARAMETER CorrelationId
        Correlation identifier propagated from the caller so a single operation can
        be traced across functions.

    .EXAMPLE
        PS> $session = Connect-ExampleService -Environment 'Test' -CorrelationId $id

        DESCRIPTION: Opens a session against the test environment.
        OUTPUT: A hashtable describing the session.
        USE CASE: Called by Get-ExampleData before querying.

    .NOTES
        Author: Jeffrey Stuhr
        Blog: https://www.techbyjeff.net
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Development', 'Test', 'Production')]
        [string]$Environment,

        [Parameter(Mandatory)]
        [guid]$CorrelationId
    )

    process {
        Write-Verbose "Connecting to $Environment - CorrelationId: $CorrelationId"

        # Stand-in for real connection latency; a genuine implementation would open
        # a session here and throw on failure so the caller's catch block runs.
        Start-Sleep -Milliseconds 20

        @{
            Environment   = $Environment
            CorrelationId = $CorrelationId
            ConnectedAt   = Get-Date
            Endpoint      = "https://example-service.yourorg.com/$($Environment.ToLower())"
        }
    }
}
