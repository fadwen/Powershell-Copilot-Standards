class ExampleServiceResult {
    <#
        Demonstrates a PowerShell class used as a descriptive output type.

        The standards discourage [OutputType([PSCustomObject])] because it tells a
        caller nothing about the shape returned. A class names the shape, provides
        IntelliSense, and lets behaviour live alongside the data.
    #>

    [string]$ServiceName
    [string]$Environment
    [ValidateSet('Healthy', 'Degraded', 'Unavailable')]
    [string]$Status
    [datetime]$CheckedAt
    [guid]$CorrelationId

    ExampleServiceResult([string]$ServiceName, [string]$Environment, [guid]$CorrelationId) {
        $this.ServiceName = $ServiceName
        $this.Environment = $Environment
        $this.Status = 'Unavailable'
        $this.CheckedAt = Get-Date
        $this.CorrelationId = $CorrelationId
    }

    [bool] IsUsable() {
        return $this.Status -in @('Healthy', 'Degraded')
    }

    [string] ToString() {
        return "$($this.ServiceName) [$($this.Environment)]: $($this.Status)"
    }
}
