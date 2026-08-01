function Get-ExampleServiceStatus {
    <#
    .SYNOPSIS
        Returns the status of a single service.

    .DESCRIPTION
        Private helper representing the one call in Get-ExampleData that can fail.

        It exists so the caller's per-item catch block is reachable. Without a
        fallible call inside the loop, error handling in an example is decorative:
        it looks like resilience but nothing can exercise it, and no test can prove
        it works.

        There is no real service. Status is derived from the environment so a batch
        returns a non-uniform result set.

    .PARAMETER ServiceName
        Service to query.

    .PARAMETER Session
        Session descriptor from Connect-ExampleService.

    .EXAMPLE
        PS> Get-ExampleServiceStatus -ServiceName 'Billing' -Session $session

        DESCRIPTION: Queries one service over an open session.
        OUTPUT: One of Healthy, Degraded, Unavailable.
        USE CASE: Called per item by Get-ExampleData.

    .NOTES
        Author: Jeffrey Stuhr
        Blog: https://www.techbyjeff.net
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [hashtable]$Session
    )

    process {
        Write-Verbose "Querying $ServiceName via $($Session.Endpoint)"

        if ($Session.Environment -eq 'Production') { 'Degraded' } else { 'Healthy' }
    }
}
