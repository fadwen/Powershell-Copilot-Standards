<#
    Class template. Replace with the types your module needs, or delete this file if
    it has none - ModuleName.psm1 tolerates an empty Classes folder.

    Two ways to give output a descriptive name, both accepted by the standards:

    1. A class, as below. Enforces shape, supports validation and methods, and gives
       callers IntelliSense. Declare it as [OutputType('TemplateResult')].
    2. A PSCustomObject carrying a PSTypeName, which Get-TemplateFunction uses.
       Lighter, but nothing enforces the shape.

    Either way the [OutputType] argument is QUOTED. [TemplateResult] is a .NET type
    reference, and fails with "Unable to find type" unless the class has already been
    loaded when the function is parsed.
#>

class TemplateResult {
    [string]$Name
    [ValidateSet('Success', 'Warning', 'Failed')]
    [string]$Status
    [datetime]$ProcessedAt
    [guid]$CorrelationId
    [string[]]$Messages

    TemplateResult([string]$Name, [guid]$CorrelationId) {
        $this.Name = $Name
        $this.Status = 'Success'
        $this.ProcessedAt = Get-Date
        $this.CorrelationId = $CorrelationId
        $this.Messages = @()
    }

    [void] AddMessage([string]$Message) {
        $this.Messages += $Message
    }

    [bool] HasFailed() {
        return $this.Status -eq 'Failed'
    }

    [string] ToString() {
        return "$($this.Name): $($this.Status) ($($this.Messages.Count) message(s))"
    }
}
