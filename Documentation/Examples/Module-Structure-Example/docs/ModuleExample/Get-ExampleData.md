---
document type: cmdlet
external help file: ModuleExample-Help.xml
HelpUri: ''
Locale: en-US
Module Name: ModuleExample
ms.date: 08 29 2026
PlatyPS schema version: 2024-05-01
title: Get-ExampleData
---

# Get-ExampleData

## SYNOPSIS

Retrieves service status for one or more services.

## SYNTAX

### __AllParameterSets

```
Get-ExampleData [-ServiceName] <string[]> [[-Environment] <string>] [[-CorrelationId] <guid>]
```

## DESCRIPTION

The exported surface of this example module.
Demonstrates the patterns the
standards require:

- An approved verb, with a descriptive [OutputType] rather than PSCustomObject
- Pipeline input, so the function composes
- A correlation ID generated once and carried through every call
- $_ in the catch block, and per-item failure that does not abort the batch

## EXAMPLES

### EXAMPLE 1

Get-ExampleData -ServiceName 'Billing'

DESCRIPTION: Queries a single service in the default environment.
OUTPUT: One ExampleServiceResult.
USE CASE: Ad-hoc check of a single service.

### EXAMPLE 2

'Billing', 'Identity' | Get-ExampleData -Environment Test

DESCRIPTION: Queries two services via the pipeline.
OUTPUT: One ExampleServiceResult per service.
USE CASE: Batch check where one failure must not stop the rest.

## PARAMETERS

### -CorrelationId

Optional correlation identifier.
One is generated when not supplied, which is
why the parameter carries no ValidateNotNullOrEmpty - it is never empty.

```yaml
Type: System.Guid
DefaultValue: '[guid]::NewGuid()'
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Environment

Environment to query.
Defaults to Development so the example is safe to run.

```yaml
Type: System.String
DefaultValue: Development
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ServiceName

One or more service names to query.
Accepts pipeline input.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

One or more service names, bound from the pipeline by value or by property name. Piping a
collection queries each service in turn; a failure on one does not stop the rest.

## OUTPUTS

### ExampleServiceResult

One object per service queried, carrying the service name, the environment, the resolved status,
and the correlation ID shared by every result in the batch.

## NOTES

Author: Jeffrey Stuhr
Blog: https://www.techbyjeff.net
LinkedIn: https://www.linkedin.com/in/jeffrey-stuhr-034214aa/

TROUBLESHOOTING:

- Connection issues: .\Troubleshooting\Common\Function-Issues.md


## RELATED LINKS

- [about_ModuleExample]()
- [Module structure standards](https://github.com/fadwen/Powershell-Copilot-Standards/blob/main/.github/instructions/module.instructions.md)
- [Help documentation standards](https://github.com/fadwen/Powershell-Copilot-Standards/blob/main/.github/instructions/platyps.instructions.md)
- [Function troubleshooting](https://github.com/fadwen/Powershell-Copilot-Standards/blob/main/Troubleshooting/Common/Function-Issues.md)

