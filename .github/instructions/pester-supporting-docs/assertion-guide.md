# Pester 6 Assertion Guide

Targets **Pester 6.1+**.

Pester 6 ships a new family of `Should-*` assertions (dash, no space) alongside the classic
`Should -Be` operator. Both work. This guide covers which to use and how they differ.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

## Which Syntax To Use

| Situation | Syntax |
| --- | --- |
| New test files | `Should-*` (preferred) |
| Editing an existing `Should -Be` file | Keep the file's existing style; do not mix within a file |
| Repo-wide migration not yet done | Leave `Should.DisableV5 = $false` (the default) |

Do not set `Should.DisableV5 = $true` until every test file in the repository has been migrated.
That switch makes any use of `Should -Be` throw.

## Why The New Syntax

The classic `Should` routes `-Be`, `-BeExactly`, `-Contain` and friends through one command. The
left side is always unwrapped by the pipeline and failure messages have to guess intent. The
`Should-*` assertions are specialized and type-aware:

- Failure messages are precise (string diffs point a caret at the first differing character;
  collection comparisons point at the first differing index).
- `$Expected` drives the comparison type, so `1 | Should-Be $true` compares as booleans.
- Type-specific switches live where they belong (`Should-BeString -IgnoreWhitespace`).
- `$null`, empty collections, and single-item arrays behave consistently.
- The set is **open** - see [Custom Assertion Guide](./custom-assertions.md) to add your own.

## Pipeline vs. -Actual

The actual value comes from the pipeline or from `-Actual`:

```powershell
1 | Should-Be -Expected 1
Should-Be -Actual 1 -Expected 1
```

The pipeline **unwraps** its input. A _value_ assertion sees `1` and `@(1)` identically, and `@()`
as `$null`. A _collection_ assertion sees the same input as `@(1)` and `@()`.

Use `-Actual` when the exact value or the concrete collection type matters:

```powershell
# Value assertions - all pass
1     | Should-Be -Expected 1
@(1)  | Should-Be -Expected 1
$null | Should-Be -Expected $null

# Collection assertions
1, 2, 3 | Should-BeCollection @(1, 2, 3)
@()     | Should-BeCollection @()

# -Actual preserves the original type; piping would re-collect as [Object[]]
Should-HaveType -Actual ([int[]](1, 2)) -Expected ([int[]])
```

When unwrapping causes a failure, the message explains what the pipeline did and points back to
`-Actual`, so this is never a silent surprise.

## Migration Map: Should -Be to Should-*

| Classic (v5) | New (v6) | Notes |
| --- | --- | --- |
| `Should -Be $x` | `Should-Be $x` | |
| `Should -Not -Be $x` | `Should-NotBe $x` | |
| `Should -BeExactly $x` | `Should-BeString $x -CaseSensitive` | For strings |
| `Should -BeOfType [T]` | `Should-HaveType ([T])` | Name changed |
| `Should -Not -BeOfType [T]` | `Should-NotHaveType ([T])` | |
| `Should -Match 'regex'` | `Should-MatchString 'regex'` | |
| `Should -Not -Match 'regex'` | `Should-NotMatchString 'regex'` | |
| `Should -BeLike 'pat*'` | `Should-BeLikeString 'pat*'` | |
| `Should -BeTrue` / `-BeFalse` | `Should-BeTrue` / `Should-BeFalse` | Strict `[bool]` |
| `Should -BeNullOrEmpty` | `Should-BeNull` / `Should-BeEmptyString` / `Should-BeFalsy` | **No single equivalent** - pick by intent |
| `Should -Not -BeNullOrEmpty` | `Should-NotBeNull` / `Should-NotBeEmptyString` / `Should-BeTruthy` | Same, pick by intent |
| `Should -BeGreaterThan $x` | `Should-BeGreaterThan $x` | |
| `Should -BeLessThan $x` | `Should-BeLessThan $x` | |
| `Should -BeGreaterOrEqual $x` | `Should-BeGreaterThanOrEqual $x` | Name changed |
| `Should -BeLessOrEqual $x` | `Should-BeLessThanOrEqual $x` | Name changed |
| `Should -Contain $item` | `Should-ContainCollection @($item)` | Now an ordered sub-collection check |
| `Should -HaveCount 3` | `Should-BeCollection -Count 3` | |
| `Should -Throw '*msg*'` | `Should-Throw -ExceptionMessage 'msg'` | See exceptions below |
| `Should -Invoke Cmd` | `Should-Invoke Cmd` | |
| `Should -Not -Invoke Cmd` | `Should-NotInvoke Cmd` | |
| `Should -InvokeVerifiable` | `Should-Invoke -Verifiable` | |
| `Should -HaveParameter Name` | `Should-HaveParameter -ParameterName Name` | |
| `Should -BeIn @(...)` | `Should-Any { $_ -eq $actual }` or keep classic | No direct 1:1 |
| `Should -Exist` | Keep classic `Should -Exist` | No `Should-*` equivalent; gained `-LiteralPath` in v6 |

`Should -BeNullOrEmpty` has no single replacement on purpose - it conflated three different
questions. Choose the one you actually mean:

```powershell
$result.Error   | Should-BeNull            # is it $null?
$result.Name    | Should-BeEmptyString     # is it ''?
$result.Items   | Should-BeFalsy           # $null, '', 0, $false, or @()
```

## The Four Families

| Family | Examples | Use for |
| --- | --- | --- |
| Value - generic | `Should-Be`, `Should-NotBe`, `Should-BeGreaterThan`, `Should-BeSame`, `Should-BeNull`, `Should-HaveType` | A single value, compared like the PowerShell operators |
| Value - type specific | `Should-BeString`, `Should-MatchString`, `Should-BeLikeString`, `Should-BeTrue`/`False`, `Should-BeFalsy`/`Truthy`, `Should-BeBefore`/`After`, `Should-BeFasterThan`/`SlowerThan` | A value of known type, with type-specific options |
| Collection - generic | `Should-BeCollection`, `Should-ContainCollection`, `Should-NotContainCollection` | Whole-collection comparison, or an ordered sub-collection |
| Collection - combinator | `Should-All`, `Should-Any` | A condition across every / any item |

Plus dedicated assertions for exceptions (`Should-Throw`), mocks (`Should-Invoke`,
`Should-NotInvoke`), command metadata (`Should-HaveParameter`), hashtable shape
(`Should-BeHashtable`), and deep comparison (`Should-BeEquivalent`).

## Common Patterns

### Strings

```powershell
'  hello ' | Should-BeString 'hello' -TrimWhitespace
'Hello'    | Should-BeString 'hello' -CaseSensitive     # fails, caret marks the first difference
'a  b'     | Should-BeString 'a b'   -IgnoreWhitespace
$name      | Should-MatchString '^[A-Z][a-z]+$'
$path      | Should-BeLikeString 'C:\Temp\*'
```

Use `-NormalizeLineEnding` whenever the actual value came off disk. It treats `` `n `` and `` `r`n ``
as equal, which is the difference between a test that passes everywhere and one that fails on
whichever platform did not write the fixture:

```powershell
"a`r`nb"                     | Should-BeString "a`nb" -NormalizeLineEnding
Get-Content $path -Raw       | Should-BeString $expected -NormalizeLineEnding
```

`Should-NotBeString` takes both `-TrimWhitespace` and `-NormalizeLineEnding`, and its `-Expected` is
mandatory.

### Booleans and null

```powershell
$true          | Should-BeTrue
$result        | Should-NotBeNull
$result.Error  | Should-BeNull
$result.Items  | Should-BeTruthy
```

### Types

```powershell
$result           | Should-HaveType ([pscustomobject])
$result.Retries   | Should-HaveType ([int])
$result           | Should-NotHaveType ([hashtable])
```

`Should-HaveType` honors `PSTypeNames`, so an object decorated with a synthetic type name - the usual
way a module brands its output - asserts against that name directly:

```powershell
$session | Should-HaveType 'MyModule.Session'
```

That is the assertion to reach for when a module's formatting or a `ValidateScript` depends on the
type name, and it beats asserting on `$session.PSTypeNames[0]` as a string.

### Collections

```powershell
1, 2, 3          | Should-BeCollection @(1, 2, 3)
1, 2, 3          | Should-BeCollection -Count 3
1, 2, 3          | Should-All { $_ -gt 0 }
1, 2, 3          | Should-Any { $_ -gt 2 }
@('a', 'b', 'c') | Should-ContainCollection @('a', 'c')   # ordered sub-collection, gaps allowed
```

`Should-ContainCollection` is order-sensitive by default. When the source genuinely has no defined
order - a hashtable's keys, a directory listing, a set of exported command names - assert with
`-IgnoreOrder` rather than sorting both sides at the call site:

```powershell
1, 2, 3                    | Should-ContainCollection @(3, 1) -IgnoreOrder
$module.ExportedFunctions.Keys | Should-ContainCollection @('Get-Thing', 'Set-Thing') -IgnoreOrder
```

### Exceptions

`Should-Throw` takes the scriptblock from the pipeline (or `-ScriptBlock`) and matches on message,
type, or error id:

```powershell
{ throw 'kaboom' } | Should-Throw -ExceptionMessage 'kaboom'

{ Get-Thing -Id $null } |
    Should-Throw -ExceptionType ([System.ArgumentNullException])

{ Get-Thing -Id 'bad' } |
    Should-Throw -FullyQualifiedErrorId 'InvalidId,Get-Thing'

# Non-terminating errors need the switch
{ Get-Thing -Id 'bad' } | Should-Throw -AllowNonTerminatingError
```

`-ExceptionMessage` matches with wildcards, so `'kaboom'` matches the whole message and
`'*kaboom*'` matches a substring. This differs from classic `Should -Throw '*kaboom*'`, where the
leading wildcard was almost always required.

Because the match is `-like`, the characters `[ ] * ?` in the expected message are **wildcards, not
literals**. A message containing brackets fails against itself unless you escape them:

```powershell
{ throw 'value is [1]' } | Should-Throw -ExceptionMessage 'value is `[1]'
{ throw 'value is [1]' } |
    Should-Throw -ExceptionMessage ([System.Management.Automation.WildcardPattern]::Escape('value is [1]'))
```

Pester detects this specific case - when the two messages differ only in those characters the
failure says so, rather than printing two strings that look identical. `Should-Throw -Because` is
named-only; it cannot be passed positionally.

There is no `Should-NotThrow`. Call the code directly - an unhandled exception fails the test:

```powershell
It 'accepts a valid id' {
    Get-Thing -Id 'valid'   # no assertion needed; a throw fails the test
}
```

### Mocks

```powershell
Should-Invoke Send-Email -Times 2 -Exactly -ParameterFilter { $To -eq 'alice@example.com' }
Should-NotInvoke Remove-Item
Should-Invoke -Verifiable
```

When a mock assertion fails, Pester 6 prints the recorded invocation history and marks which calls
matched the `-ParameterFilter` with `[*]`:

```text
[-] emails alice exactly twice
 Expected Send-Email to be called 2 times exactly, but was called 1 times
 Performed invocations:
   [*] Send-Email -To 'alice@example.com' -Subject 'Welcome' from Order.Tests.ps1:7
   [ ] Send-Email -To 'bob@example.com'   -Subject 'Receipt' from Order.Tests.ps1:7
```

### Command metadata

```powershell
Get-Command Get-Thing | Should-HaveParameter -ParameterName Name -Type ([string[]]) -Mandatory
Get-Command Get-Thing | Should-HaveParameter -ParameterName Path -DefaultValue '.'
Get-Command Get-Thing | Should-NotHaveParameter -ParameterName Force
```

### Time and duration

```powershell
{ Invoke-Thing }               | Should-BeFasterThan '100ms'
{ Invoke-Thing }               | Should-BeSlowerThan '10ms'
[datetime]::Now.AddMinutes(11) | Should-BeAfter 10minutes -Ago
$record.Created                | Should-BeBefore ([datetime]::Now)
```

`Should-BeFasterThan` replaces hand-rolled `Measure-Command` plus `Should -BeLessThan` and avoids
the TimeSpan-vs-double comparison mistakes that pattern invites. Its `-Expected` is mandatory, as is
`Should-BeSlowerThan`'s - a bare `Should-BeFasterThan` no longer binds to a silent default.

### Deep object comparison

`Should-BeEquivalent` walks nested properties, hashtables, dictionaries, and collections and emits
a property-by-property diff. Use it for whole API responses or configuration objects:

```powershell
$user | Should-BeEquivalent ([pscustomobject]@{
    Name    = 'Jakub'
    Age     = 31
    Address = [pscustomobject]@{ City = 'Prague'; Country = 'CZ' }
    Roles   = @('admin', 'user')
})
```

The comparison is **strict and symmetric** by default - an extra property on the actual object
fails. Compare like with like (object to object, hashtable to hashtable). Two options relax it:

```powershell
# Assert a subset: properties absent from $expected are never looked at
$user | Should-BeEquivalent ([pscustomobject]@{ Name = 'Jakub' }) -ExcludePathsNotOnExpected

# Full comparison except volatile fields; dot-notation reaches nested members
$actual | Should-BeEquivalent $expected -ExcludePath 'Id', 'Metadata.Timestamp'

# Non-recursive equality when that is all you need
$actual | Should-BeEquivalent $expected -Comparator Equality
```

Prefer `-ExcludePathsNotOnExpected` over listing every field you do not care about. It keeps tests
focused and resilient: a new field on the object under test will not break an assertion that never
claimed to care about it.

## Writing Your Own

The `Should-*` family is open for extension. Declare a function, call `New-ShouldAssertion` inside
it, and the result collects pipeline input, formats values, and fails through the same path a
built-in assertion uses - so soft assertions and mock parameter filters work with no extra effort:

```powershell
function Assert-BeValidSemVer {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)] $Actual,
        [string] $Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $Input
    $Actual = $assert.Actual()

    $parsed = $null
    if (-not [version]::TryParse($Actual, [ref] $parsed) -or $parsed.Build -lt 0) {
        $assert.Fail(
            'Expected a Major.Minor.Patch version,<because> but got <actual>.',
            @{ Because = $Because })
    }
}

Set-Alias -Name Should-BeValidSemVer -Value Assert-BeValidSemVer
```

Reach for this only when the same non-trivial check recurs across files **and** naming the offending
value is the point. See [Custom Assertion Guide](./custom-assertions.md) for the full treatment -
`-As` modes, message tokens, the `Assert-` verb packaging rule, and how to test the assertion itself.

This replaces `Add-ShouldOperator` for new work. That mechanism still exists for the classic `Should`
syntax, but it is a different shape and the runspace caps out at 32 operators.

## Soft Assertions

Both syntaxes honor `Should.ErrorAction = 'Continue'`, which collects every failure in an `It`
instead of stopping at the first:

```powershell
$config = New-PesterConfiguration
$config.Should.ErrorAction = 'Continue'
```

```powershell
It 'has the expected shape' {
    $user.Name | Should-Be 'Jakub'
    $user.Age  | Should-Be 31
    $user.City | Should-Be 'Prague'
}
```

All three run and every failure is reported at the end of the test. Use this for shape assertions
on a single object. Keep the default `'Stop'` elsewhere, so a failed precondition does not cascade
into a wall of downstream noise.

## Assertion Selection Guidelines

- Assert on the narrowest thing that proves the behavior. `Should-Be 'Active'` beats
  `Should-NotBeNull`.
- Prefer `Should-BeEquivalent -ExcludePathsNotOnExpected` over a run of six property assertions.
- Use `Should-HaveType` rather than asserting on `.GetType().Name` as a string.
- Use `-Because` to record intent on non-obvious assertions:
  `$retries | Should-Be 3 -Because 'the transient-failure policy caps retries at 3'`.
- Do not assert on the text of a message you also control and change often; assert on the error
  type or id instead.
- Write a [custom assertion](./custom-assertions.md) only when the same domain rule is asserted in
  several files and the built-in failure message cannot name what went wrong.
