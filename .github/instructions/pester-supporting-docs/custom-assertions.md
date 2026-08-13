# Custom Assertion Guide

Requires **Pester 6.1+**. `New-ShouldAssertion` does not exist in 6.0.x.

**NOTE**: Do not use Unicode emojis in any generated code, documentation, or test output. Use plain
text descriptions and standard ASCII characters only.

In Pester 6.0 the `Should-*` family was a closed set - extending it meant dropping back to the v5
`Add-ShouldOperator` mechanism, a different shape that caps out at 32 operators. Pester 6.1 opens the
family up: write an ordinary function, call `New-ShouldAssertion` inside it, and the result behaves
exactly like a built-in assertion.

## When To Write One

Write a custom assertion when the same non-trivial check appears across several test files and the
built-in failure message cannot explain it. The bar is the failure message: if a custom assertion
does not produce a better one than `Should-BeTrue` plus `-Because`, it is not worth the indirection.

| Situation | Do this |
| --- | --- |
| One test needs a bespoke check | Plain PowerShell plus `Should-Be` |
| A property-by-property object shape check | `Should-BeEquivalent -ExcludePathsNotOnExpected` |
| A condition across every item | `Should-All { ... }` |
| A domain rule repeated across files, where naming the violating item is the point | Custom assertion |

A custom assertion inherits all of the shared machinery for free: pipeline input collection, Pester's
value formatting, the diagnostic hint when a collection is piped into a value assertion, soft
assertions via `Should.ErrorAction = 'Continue'`, and use inside a mock `-ParameterFilter`.

## The Shape

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

```powershell
'1.2.3'                    | Should-BeValidSemVer          # passes
$manifest.ModuleVersion    | Should-BeValidSemVer -Because 'the module is published to a gallery'
# Expected a Major.Minor.Patch version, because the module is published to a gallery, but got '1.0'.
```

Three rules cover most of it:

1. **Call `New-ShouldAssertion` once, at the top**, passing the assertion's own `$PSCmdlet`,
   its `-Actual` value, and `$Input`. Pass all three even when one is usually empty - `-Actual` is
   `$null` for a piped call and `$Input` is empty for an `-Actual` call, and the helper resolves
   which one was used.
2. **Read the value back through `$assert.Actual()`**, never from `$Actual` directly. That is what
   applies the pipeline-collection rules and preserves shapes a bare read would flatten.
3. **A pass is implicit.** Return without calling `Fail()`. There is nothing to signal success with.

Do not add a `process` block. The assertion body must run as an `end` block - the default when a
function declares no named blocks - because `$Input` only holds the whole pipeline there. Pester's
own examples write `end { ... }` explicitly; both forms are equivalent.

A `process` block does not error, which is what makes it worth calling out. It quietly changes the
assertion's semantics: the body runs **once per piped item** instead of once for the pipeline, so
the assertion inspects items individually rather than as one value the way every built-in
`Should-*` does. The diagnostic hint also becomes nonsense, because it describes a collection that
the assertion never saw:

```powershell
'ok', 'bad' | Should-BeOk
```

```text
# end block (correct)   - invoked once,        "Expected ok but got @('ok', 'bad')."
# process block (wrong) - invoked twice,       "Expected ok but got 'bad'."
#                         and the hint claims the collection was "re-collected into a single [string]"
```

If you want per-item semantics, that is what `Should-All` is for.

### Parameter Positions

6.1 aligned `-Actual` across every built-in assertion, and custom assertions should match so they
read the same at a call site. `-Actual` always takes `ValueFromPipeline`; its position depends on
whether the assertion has a comparand:

| Assertion shape | `-Expected` | `-Actual` | Built-in example |
| --- | --- | --- | --- |
| Single-subject - nothing to compare against | none | `Position = 0` | `Should-BeNull`, `Should-BeTrue`, `Should-BeHashtable` |
| Two-subject - a positional comparand | `Position = 0`, mandatory | `Position = 1` | `Should-Be`, `Should-BeString`, `Should-HaveType` |

Verify against the installed version rather than trusting a doc, including this one:

```powershell
Get-Command -Syntax Should-BeHashtable
```

## Collecting The Input: -As

`-As` selects both how the piped input is collected and how the diagnostic hint is worded when the
assertion fails.

| `-As` | Input handling | Use for |
| --- | --- | --- |
| `Scalar` (default) | Unrolls a single piped value | A value assertion, like `Should-Be` |
| `ExactType` | Unrolls, preserving the concrete type | A value assertion that inspects the type |
| `Collection` | Keeps the input as a collection | A whole-collection assertion, like `Should-BeCollection` |
| `CollectionItems` | Keeps the input as a collection, hints about items | An assertion that reports on individual items |
| `None` | No unrolling, no input hint | A structural comparison, like `Should-BeEquivalent` |

```powershell
function Assert-HaveTag {
    [CmdletBinding()]
    param (
        [Parameter(Position = 1, ValueFromPipeline)] $Actual,
        [Parameter(Position = 0, Mandatory)] [string] $Expected,
        [string] $Because
    )

    $assert = New-ShouldAssertion -Caller $PSCmdlet -Actual $Actual -Buffer $Input -As Collection
    $Actual = $assert.Actual()

    $missing = @($Actual | Where-Object { $_.Tag -notcontains $Expected })
    if (0 -lt $missing.Count) {
        $assert.Fail(
            'Expected every block to be tagged <expected>,<because> but <Untagged> were not.',
            @{ Expected = $Expected; Because = $Because; Untagged = $missing.Name })
    }
}

Set-Alias -Name Should-HaveTag -Value Assert-HaveTag
```

```powershell
$result.Blocks | Should-HaveTag 'Unit' -Because 'the tagging audit depends on it'
# Expected every block to be tagged 'Unit', because the tagging audit depends on it,
# but @('Connectivity', 'Retry') were not.
```

Naming the violating items is the whole reason to write this instead of
`$result.Blocks | Should-All { $_.Tag -contains 'Unit' }`.

## The Failure Message

`Fail(message)` or `Fail(message, data)`. The message is a template; `data` is a hashtable.

Four keys in `data` are **reserved** and are not turned into tokens:

| Key | Effect |
| --- | --- |
| `Expected` | Fills `<expected>` and `<expectedType>` |
| `Actual` | Fills `<actual>` and `<actualType>`; defaults to the collected input when omitted |
| `Because` | Fills `<because>`, formatted as `, because <text>` (empty when `-Because` was not passed) |
| `Hint` | Replaces the default input hint, printed as `Hint: <text>` after a blank line |

Every other key becomes a `<key>` token.

| Token | Renders |
| --- | --- |
| `<expected>` | `data.Expected`, through Pester's formatter |
| `<actual>` | `data.Actual`, or the collected input |
| `<expectedType>` / `<actualType>` | The short type name, e.g. `[string]` |
| `<because>` | `, because <text>`, or nothing |
| `<YourKey>` | `data.YourKey`, through Pester's formatter |

**`<because>` is only filled when you pass `Because` in the data.** Declaring a `-Because` parameter
is not enough - the value has to be threaded through:

```powershell
$assert.Fail('Expected <expected>,<because> but got <actual>.', @{ Expected = $Expected; Because = $Because })
```

**Custom tokens are case-sensitive and must match the hashtable key exactly.** A key of `Untagged`
fills `<Untagged>`; `<untagged>` is left in the message as literal text. Only the built-in tokens are
lowercase. The failure is silent - the raw token ships in the message - so read the message once when
you write the assertion.

Write the comma before `<because>` rather than inside it, as the examples do. When `-Because` is
absent the token renders as nothing and the sentence still reads correctly.

### Hint

Use the `Hint` key when the assertion knows something more specific than the generic input hint:

```powershell
$assert.Fail(
    'Expected at most 5 characters,<because> but <actual> has <Length>.',
    @{ Because = $Because; Length = $Actual.Length
       Hint = 'Rename the function rather than abbreviating the noun.' })
```

Left alone, the default hint covers the common shape mistake:

```text
Expected a Major.Minor.Patch version, but got @('1.2.3', '2.0.0').

Hint: You piped a [Object[]] into a single-value assertion, but the pipeline streams a multi-item
collection and re-collects it into a single [Object[]], so the whole collection was inspected as one
value. To assert on a collection use Should-BeCollection or Should-BeEquivalent; to assert on a
single value pass it as the -Actual argument instead of piping it, e.g. -Actual $value.
```

## Other Members On $assert

| Member | Purpose |
| --- | --- |
| `Actual()` | The collected value to assert on |
| `Fail(message [, data [, pretty]])` | Report a failure; `pretty` formats values across multiple lines |
| `EnsureScalar(expected)` | Returns `expected`, or throws when it is a collection |
| `Format(value)` | Formats a value the way Pester does in messages |
| `IsCollection(value)` | Whether a value is treated as a collection |
| `Hint()` | The default input hint, for assertions that inspect it before failing |

`EnsureScalar` guards the **expected** side of an assertion that only makes sense against one value.
Call it before comparing:

```powershell
$Expected = $assert.EnsureScalar($Expected)
```

```text
5 | Should-BeUnder @(1, 2)
# You provided a collection to the -Expected parameter. Using a collection on the -Expected side is
# not allowed by this assertion, because it leads to unexpected behavior. To compare collections use
# Should-BeCollection, or a more specialized collection assertion such as Should-Any or Should-All.
```

Guard the actual side too when the check does arithmetic or calls a type-specific method. Pester's
hint appears on a `Fail()`, so an assertion that crashes on `@(1, 3) % 2` before reaching `Fail()`
produces a raw PowerShell error instead. Test the type first and fail properly.

## Packaging: Name It Assert-, Export It As Should-

`Should` is not an approved PowerShell verb. A module that exports `Should-*` functions makes
`Import-Module` print the unapproved-verb warning to every consumer. An explicit `FunctionsToExport`
in the manifest does not suppress it, and `-DisableNameChecking` only moves the problem onto your
users.

Name the function with the approved `Assert` verb and export a `Should-*` alias. Aliases are not
verb-checked:

```powershell
function Assert-BeValidSemVer { ... }

Set-Alias -Name Should-BeValidSemVer -Value Assert-BeValidSemVer
Export-ModuleMember -Function Assert-BeValidSemVer -Alias Should-BeValidSemVer
```

```powershell
# TestHelpers/Assertions.psd1
@{
    RootModule        = 'Assertions.psm1'
    FunctionsToExport = @('Assert-BeValidSemVer', 'Assert-HaveTag')
    AliasesToExport   = @('Should-BeValidSemVer', 'Should-HaveTag')
}
```

Nothing in Pester keys off the assertion's name - it all keys off the `$PSCmdlet` passed as
`-Caller` - so the assertion behaves identically when called through the alias.

This only applies to modules. A test file that defines or dot-sources a `Should-*` function directly
needs none of it.

## Where To Put Them

Custom assertions are shared test infrastructure, so they follow the same rule as every other
discovery-time dependency: **each test file loads its own.** See
[Test Structure Guide](./test-structure-guide.md).

```text
Tests/
  TestHelpers/
    Assertions.psd1
    Assertions.psm1
    Assertions.Tests.ps1     # the assertions are code; test them
  Unit/
```

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../TestHelpers/Assertions.psd1" -Force
    Import-Module "$PSScriptRoot/../../MyModule.psd1" -Force
}
```

For a repository-wide set, import them from a `Pester.BeforeContainer.ps1` at the repository root,
which Pester dot-sources before every container:

```powershell
# Pester.BeforeContainer.ps1, at the repository root
Import-Module "$PSScriptRoot/Tests/TestHelpers/Assertions.psd1" -Force
```

That file fires only when `Run.RepoRoot` points at the directory holding it - see
[Pester Configuration Guide](./pester-configuration.md).

## Test The Assertion Itself

An assertion that cannot fail is worse than no assertion, and this is exactly the failure mode
custom assertions invite. Cover the pass, the fail, and the message:

```powershell
Describe 'Should-BeValidSemVer' -Tag 'Unit', 'TestHelpers' {
    It 'passes on <_>' -ForEach '1.2.3', '0.0.1', '10.20.30' {
        $_ | Should-BeValidSemVer
    }

    It 'fails on <_>' -ForEach '1.0', 'v1.2.3', 'not-a-version' {
        { $_ | Should-BeValidSemVer } | Should-Throw
    }

    It 'names the offending value and the reason' {
        try {
            '1.0' | Should-BeValidSemVer -Because 'the module is published'
            throw 'the assertion did not fail'
        }
        catch [Exception] {
            $_.Exception.Message |
                Should-BeString "Expected a Major.Minor.Patch version, because the module is published, but got '1.0'."
        }
    }
}
```

The third test is the one that catches an unexpanded `<key>` token, which no amount of pass/fail
coverage will.

## Soft Assertions And Mock Filters

Both work with no extra code, because `Fail()` goes through the shared failure path:

```powershell
$config.Should.ErrorAction = 'Continue'    # collects every failure in the It, custom ones included
```

```powershell
Should-Invoke Publish-Module -Times 1 -ParameterFilter {
    $Version | Should-BeValidSemVer
    $true
}
```

Inside a `-ParameterFilter` a passing assertion emits `$true` on its own pipeline, so the filter
matches; a failing one throws out of the filter. The trailing `$true` keeps the filter's result
explicit when the assertion is not the last statement.
