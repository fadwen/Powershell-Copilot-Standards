---
applyTo: "**/docs/**/*.md,**/Public/*.ps1,**/*.psd1"
tools: ['codebase', 'githubRepo']
description: 'Generates and maintains module help documentation with Microsoft.PowerShell.PlatyPS, shipping MAML external help'
---

# PowerShell Help Documentation with PlatyPS

Every module generates its command help with **Microsoft.PowerShell.PlatyPS** and ships compiled
MAML external help. Markdown under `docs/` is the source you edit; `en-US/<ModuleName>-Help.xml` is
the build output that `Get-Help` actually reads.

## Use the Supported Module

**Target version: Microsoft.PowerShell.PlatyPS 1.0.3+.**

```powershell
Install-PSResource -Name Microsoft.PowerShell.PlatyPS
```

The original `platyPS` v0.14.2 is **no longer supported**. It is a different module with different
cmdlet names, and its Markdown uses an older schema. Never generate `platyPS` 0.14 commands:

| Do not use (platyPS 0.14.2) | Use instead (Microsoft.PowerShell.PlatyPS 1.x) |
|---|---|
| `New-MarkdownHelp` | `New-MarkdownCommandHelp` |
| `Update-MarkdownHelp` | `Update-MarkdownCommandHelp` |
| `New-ExternalHelp` | `Export-MamlCommandHelp` |
| `New-ExternalHelpCab` | `New-HelpCabinetFile` |
| `Get-HelpPreview` | `Show-HelpPreview` |
| `Update-MarkdownHelpModule` | `Update-MarkdownModuleFile` |

`Update-MarkdownCommandHelp` can read 0.14.2-era Markdown and rewrite it in the current schema, so
migrating an existing project does not mean starting the documentation over. See
[Migrating existing docs](#migrating-existing-014-documentation).

## Authoring Model

Markdown is the source of truth for public command help. Comment-based help seeds it once, then the
Markdown is what you edit. The seeding only works if `.EXTERNALHELP` is added _after_ the first
generation — see [that ordering rule](#add-it-after-first-generation-not-before).

```text
Public/Get-Thing.ps1
  |  <# .EXTERNALHELP ModuleName-Help.xml      <-- required; see below
  |     .SYNOPSIS  one line for source readers #>
  |
  |  New-MarkdownCommandHelp        (once, at first generation)
  |  Update-MarkdownCommandHelp     (every time the signature changes)
  v
docs/ModuleName/Get-Thing.md        <-- EDIT HERE. Canonical. Committed.
docs/ModuleName/ModuleName.md       <-- module page. Committed.
  |
  |  Export-MamlCommandHelp         (build step)
  v
en-US/ModuleName-Help.xml           <-- build output. What Get-Help reads.
```

Consequences to hold onto:

- **Do not hand-edit `en-US/*.xml`.** It is generated and will be overwritten.
- **Do not treat the `.ps1` help block as the place to add detail.** Parameter descriptions,
  examples, notes, and links belong in the Markdown. A public function's comment block shrinks to
  `.EXTERNALHELP` plus a one-line `.SYNOPSIS`.
- **Private functions are the exception.** They are never exported, so PlatyPS never sees them and
  they get no Markdown. They keep full comment-based help — see
  [comments.instructions.md](./comments.instructions.md).

## `.EXTERNALHELP` Is Mandatory on Public Functions

This is the single detail that decides whether shipped MAML is used or silently ignored.

**Comment-based help takes precedence over XML-based help.** If a public function keeps a normal
help block and the module also ships `ModuleName-Help.xml`, `Get-Help` displays the comment block
and the MAML you built is dead weight. The `.EXTERNALHELP` keyword reverses that precedence.

Put the keyword **inside the same `<# #>` block** as the synopsis, as its first entry:

```powershell
function Get-ServerHealth {
    <#
    .EXTERNALHELP ModuleName-Help.xml
    .SYNOPSIS
        Collects health metrics from one or more servers.
    #>
    [CmdletBinding()]
    [OutputType('ServerHealth')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$ComputerName
    )

    # ...
}
```

### Add It After First Generation, Not Before

`.EXTERNALHELP` suppresses comment-based help for `Get-Help` — and `New-MarkdownCommandHelp` reads
`Get-Help` to populate descriptions and examples. Add the keyword to a function that has never been
generated and PlatyPS sees no prose to seed from, so it emits `{{ Fill in }}` placeholders and the
comment-based help you already wrote is thrown away.

The order for a new public function is therefore:

1. Write full comment-based help in the `.ps1`, as
   [comments.instructions.md](./comments.instructions.md) describes.
2. Run `New-MarkdownCommandHelp` — the prose lands in the Markdown.
3. Add `.EXTERNALHELP ModuleName-Help.xml` and trim the block to a one-line `.SYNOPSIS`.

Getting this backwards is silent: the build succeeds and the published help is empty.

### Rules for the Keyword

- The value is a **filename with no path**. `Get-Help` resolves it against the culture-specific
  subdirectory of the module folder, so `ModuleName-Help.xml` is correct and
  `.\en-US\ModuleName-Help.xml` is not.
- **The capital `H` in `-Help.xml` is not a typo.** `Export-MamlCommandHelp` emits
  `<ModuleName>-Help.xml`, while most documentation and the PowerShell 5.0+ auto-discovery
  convention write `-help.xml`. On Windows the mismatch is invisible; on Linux and macOS the
  lookup fails and every command loses its help. Copy the name PlatyPS actually produced rather
  than the one you expect — check with `Get-ChildItem ./maml/ModuleName/`.
- The value must be on the **same line** as the keyword. Any other placement is silently ignored.
- It wins **even when the XML file is missing**. This is the development-time gotcha below.

### Keep It Inside the Block

A `# .EXTERNALHELP` single-line comment also works, but it has a failure mode that produces no
error and no warning. Comment-based help must be contiguous, and a comment group that opens with
ordinary prose is disqualified as a help topic unless a blank line separates the prose from the
keyword. When a separate `<# #>` block follows, that block then wins and the keyword is ignored —
`Get-Help` quietly serves the stub synopsis and the MAML is never read.

Tested against PowerShell 7.6, with the same MAML present in `en-US/` in every case:

| Arrangement | MAML used |
|---|---|
| `.EXTERNALHELP` inside the `<# #>` block with `.SYNOPSIS` | yes |
| `# .EXTERNALHELP` alone, no other help block | yes |
| `# .EXTERNALHELP` alone, then a separate `<# .SYNOPSIS #>` block | yes |
| prose comment, blank line, `# .EXTERNALHELP`, then a separate block | yes |
| **prose comment, no blank line, `# .EXTERNALHELP`, then a separate block** | **no** |

Only the last row fails, and it is the arrangement a helpful comment above the keyword naturally
produces. Putting the keyword inside the block avoids the question entirely.

### Development-Time Gotcha

Before `Export-MamlCommandHelp` has run — a fresh clone, a working tree, a dot-sourced `.ps1` —
`Get-Help Get-ServerHealth` shows only autogenerated syntax. `.EXTERNALHELP` suppressed the comment
block and the XML does not exist yet. This is expected, not a bug.

Two ways to see real help while developing:

```powershell
# Preview a built MAML file as Get-Help would render it
Show-HelpPreview -Path ./maml/ModuleName/ModuleName-Help.xml

# Or build the MAML into the module first, then use Get-Help normally
./build.ps1 -Task Docs
```

Make the docs build part of the normal local build so a working tree always has current help.

## First-Time Generation

Import the module, then generate command Markdown and the module page together:

```powershell
Import-Module ./ModuleName.psd1 -Force

$newMarkdownSplat = @{
    ModuleInfo     = Get-Module -Name ModuleName
    OutputFolder   = './docs'
    WithModulePage = $true
    Locale         = 'en-US'
}
New-MarkdownCommandHelp @newMarkdownSplat
```

**Always pass `-Locale` explicitly.** It defaults to the generating machine's culture, so a
developer running in `en-GB` or `en-AE` stamps that into the front matter of every file while the
MAML still ships to `en-US/`. The mismatch does not fail the build; it just makes the committed
Markdown disagree with the folder it compiles into, and the next person on a different machine sees
a diff on every file.

This creates `./docs/ModuleName/` containing one `.md` per exported command plus `ModuleName.md`,
the module page listing every command with its synopsis.

PlatyPS writes **templates, not content**. Every generated file contains placeholder strings such as
`{{ Fill in the Description }}`. Filling those in is the actual documentation work, and the standards
in [comments.instructions.md](./comments.instructions.md) — business value in the description,
validation rules and business context per parameter, three progressive examples, troubleshooting
links in notes — apply to the Markdown now. A file still containing `{{ Fill in` is not done.

If you generated without `-WithModulePage`, add the module page later, once synopses are written:

```powershell
Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Import-MarkdownCommandHelp -Path {$_.FilePath} |
    New-MarkdownModuleFile -OutputFolder ./docs -Force
```

> **`-Path {$_.FilePath}` is not a typo.** The braces are a delayed-binding script block, evaluated
> once per pipeline item. Writing `-Path $_.FilePath` binds a single value before the pipeline runs
> and fails. This shape recurs in every PlatyPS pipeline below.

## Updating When the Module Changes

Whenever a public function gains a parameter, changes a type, adds a parameter set, or is added or
removed, refresh the Markdown from the loaded module. Do not hand-patch the syntax blocks.

```powershell
Import-Module ./ModuleName.psd1 -Force

Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Update-MarkdownCommandHelp -Path {$_.FilePath}
```

`Update-MarkdownCommandHelp` is deliberately conservative: it adds what it can verify and does not
delete your prose. It writes backups next to the originals — diff against them before committing.

Then refresh the module page:

```powershell
Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Import-MarkdownCommandHelp -Path {$_.FilePath} |
    Update-MarkdownModuleFile -Path ./docs/ModuleName/ModuleName.md
```

Two things the update cannot infer, which you must check by hand every time:

- **Output types.** PlatyPS reads them from `Get-Command`, so they are only as good as the
  `[OutputType()]` attribute. It adds what it can verify and never removes what it cannot.
- **Wildcard support.** Only reflected when the parameter carries `[SupportsWildcards()]`. Add the
  attribute rather than documenting the behaviour in prose alone.

New commands added since the last run have no Markdown to update. Run `New-MarkdownCommandHelp` for
those, or regenerate into the same folder — without `-Force`, existing files are left alone.

## Validating

Structure validation belongs in the build, before MAML is generated:

```powershell
Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Test-MarkdownCommandHelp -Path {$_.FilePath} -DetailView
```

`Test-MarkdownCommandHelp` returns `True` for a file whose `## RELATED LINKS` entries are relative
paths, but `Get-Help` throws `The specified URI ... is not valid` at read time and returns nothing.
A `.LINK` value must be a bare topic name or an absolute `http`/`https` URL — never a relative path
to a file in the repository. PlatyPS writes a bare topic as `[Get-Thing]()`, so the check
below has to allow empty parentheses while still rejecting a path. Check before building:

```powershell
# The |\) in the lookahead is what permits a bare topic name. Without it this flags every
# [Get-Thing]() cross-reference as a relative link - rejecting the exact form the paragraph
# above calls correct.
Select-String -Path ./docs/ModuleName/*.md -Pattern '^\s*-?\s*\[.+\]\((?!https?://|\))' |
    ForEach-Object { Write-Error "Relative link in $($_.Filename):$($_.LineNumber)" -ErrorAction Stop }
```

Both forms are legal, and they are not interchangeable:

| Target | Form | Renders as |
|---|---|---|
| A command in this module, or an `about_` topic | `- [Get-Thing]()` | the plain name |
| Anything outside the installed module | `- [Title](https://...)` | the URL |

Use the bare form for anything `Get-Help` can resolve on its own — sibling commands above all.
Reaching for an absolute URL there is the common mistake: it still passes the gate, but
`Get-Help -Full` then prints a GitHub URL where a command name would read better, and the link stops
working the moment the repository moves or goes private. Reserve URLs for material that genuinely
lives outside the module, remembering that a user who installed from the Gallery has no repository
checkout — which is also why a relative path would be useless even if `Get-Help` accepted it.

[Module-Structure-Example](../../Documentation/Examples/Module-Structure-Example/docs/ModuleExample/Get-ExampleData.md)
shows both forms in one file.

Also fail the build on leftover placeholders — `Test-MarkdownCommandHelp` checks structure, not
whether anyone wrote the content:

```powershell
$unfilled = Select-String -Path ./docs/ModuleName/*.md -Pattern '\{\{\s*Fill in' -List
if ($unfilled) {
    $names = ($unfilled.Path | Split-Path -Leaf) -join ', '
    Write-Error "Help templates still contain placeholders: $names" -ErrorAction Stop
}
```

### Exclude Generated Help From the Prose Linter

PlatyPS Markdown does not satisfy a normal markdownlint configuration, and the violations are
structural rather than fixable:

- **MD040** — the `## SYNTAX` code fence carries no language label
- **MD013** — the module page writes the manifest `Description` as one unwrapped line

Both are rewritten on every `Update-MarkdownCommandHelp` run, so a hand-correction lasts until the
next regeneration and then reappears in the diff. Exclude the generated help instead of fighting it:

```yaml
- name: Lint Markdown
  uses: DavidAnson/markdownlint-cli2-action@v14
  with:
    globs: |
      **/*.md
      !**/docs/*/*.md
    config: '.markdownlint.json'
```

A `.markdownlintignore` file does **not** work here — `markdownlint-cli2` ignores it once explicit
globs are passed on the command line. Use a negated glob in the same list.

## Building MAML

```powershell
Measure-PlatyPSMarkdown -Path ./docs/ModuleName/*.md |
    Where-Object Filetype -match 'CommandHelp' |
    Import-MarkdownCommandHelp -Path {$_.FilePath} |
    Export-MamlCommandHelp -OutputFolder ./maml -Force
```

This writes `./maml/ModuleName/ModuleName-Help.xml`. Copy it into the module's culture folder as
part of packaging:

```powershell
$cultureDir = Join-Path $ModuleOutputPath 'en-US'
New-Item -Path $cultureDir -ItemType Directory -Force | Out-Null
Copy-Item -Path ./maml/ModuleName/ModuleName-Help.xml -Destination $cultureDir -Force
```

The filename must match the value in every `.EXTERNALHELP` keyword. Add a culture folder per
language if the module is localized.

## Module Layout

```text
ModuleName/
├── ModuleName.psd1
├── ModuleName.psm1
├── Public/
│   └── Get-Thing.ps1               # carries `.EXTERNALHELP ModuleName-Help.xml`
├── Private/
├── docs/                           # PlatyPS Markdown - SOURCE, committed
│   └── ModuleName/
│       ├── ModuleName.md           # module page
│       └── Get-Thing.md            # one per exported command
├── en-US/                          # packaged with the module
│   ├── ModuleName-Help.xml         # generated by Export-MamlCommandHelp
│   └── about_ModuleName.help.txt   # hand-written, see below
└── Tests/
```

`maml/` is a build intermediate — add it to `.gitignore`. Whether `en-US/` is committed or produced
only at package time is a per-project call; if it is committed, the drift gate below is what keeps
it honest.

### About Topics

`about_*.help.txt` files are plain text, hand-written, and not produced by PlatyPS. Place them in
the same culture folder. A module with more than a handful of commands should have one covering
concepts that do not belong to any single command — authentication setup, configuration precedence,
correlation ID conventions.

## CI Drift Gate

Stale MAML is worse than no MAML: `.EXTERNALHELP` guarantees users see the stale content instead of
falling back to anything correct. CI must fail when the checked-in docs no longer match the module.

```powershell
#Requires -Modules @{ ModuleName = 'Microsoft.PowerShell.PlatyPS'; ModuleVersion = '1.0.3' }

Import-Module ./ModuleName.psd1 -Force

$documented = (Get-ChildItem ./docs/ModuleName/*.md).BaseName |
    Where-Object { $_ -ne 'ModuleName' }
$exported = (Get-Module ModuleName).ExportedFunctions.Keys

$missing = $exported | Where-Object { $_ -notin $documented }
$orphan = $documented | Where-Object { $_ -notin $exported }

if ($missing) {
    Write-Error "Exported commands with no help Markdown: $($missing -join ', ')" -ErrorAction Stop
}
if ($orphan) {
    Write-Error "Help Markdown for commands that no longer exist: $($orphan -join ', ')" -ErrorAction Stop
}
```

That catches added and removed commands. To also catch a changed **signature** — a new parameter, a
changed type, a new parameter set — compare the committed Markdown against the loaded module:

```powershell
$committed = Import-MarkdownCommandHelp -Path ./docs/ModuleName/Get-Thing.md
$current = New-CommandHelp -Command (Get-Command Get-Thing)

$diff = Compare-CommandHelp -ReferenceCommandHelp $committed -DifferenceCommandHelp $current
if ($diff) {
    Write-Error 'Help Markdown is out of date - run the docs update task' -ErrorAction Stop
}
```

Run this on the same pull request trigger as the Pester and PSScriptAnalyzer gates. See
[cicd.instructions.md](./cicd.instructions.md).

## Migrating Existing 0.14 Documentation

1. Do not import `platyPS` 0.14.2 and `Microsoft.PowerShell.PlatyPS` in the same session. Start a
   clean session for the migration.
2. Run `Update-MarkdownCommandHelp` over the existing files. It reads the old schema and rewrites in
   the current one.
3. Fill in the new `## ALIASES` section that appears in every converted file. It is optional content
   — delete the section if the command has no aliases — but the placeholder must not survive.
4. Add `.EXTERNALHELP ModuleName-Help.xml` to every public function, and cut the now-duplicated
   comment-based help down to a one-line `.SYNOPSIS`.
5. Diff every file against its backup before committing. Conversion is mechanical; the review is not.

## Checklist

Before a module is considered documented:

- [ ] `Microsoft.PowerShell.PlatyPS` 1.0.3+ is used, and no `platyPS` 0.14 cmdlet names appear
      anywhere in build scripts or workflows
- [ ] Every exported function carries `.EXTERNALHELP ModuleName-Help.xml` with the filename only,
      on the same line as the keyword
- [ ] Every exported function has a Markdown file under `docs/ModuleName/`, and no Markdown file
      exists for a command that is no longer exported
- [ ] No `{{ Fill in` placeholder survives in any committed Markdown
- [ ] Every command has at least three examples, each with a description and expected output
- [ ] `[OutputType()]` and `[SupportsWildcards()]` are present on the source functions so PlatyPS
      can reflect them accurately
- [ ] The module page `ModuleName.md` lists every command with a real synopsis
- [ ] `Test-MarkdownCommandHelp` passes in the build
- [ ] MAML is built to `en-US/ModuleName-Help.xml` and packaged with the module, with the filename
      byte-for-byte identical to every `.EXTERNALHELP` value including the capital `H`
- [ ] `Get-Help <Command> -Full` verified against the packaged module on a case-sensitive
      filesystem, not only on Windows
- [ ] `maml/` is gitignored; `en-US/*.xml` is never hand-edited
- [ ] The CI drift gate fails on a command documented but not exported, or exported but not
      documented
- [ ] Private functions retain full comment-based help — PlatyPS does not document them

## Related Instructions

- [Comment Standards](./comments.instructions.md) — content quality standards, which now apply to
  the Markdown, and full comment-based help for private functions
- [Module Development](./module.instructions.md) — module layout and manifest
- [CI/CD Integration](./cicd.instructions.md) — where the docs build and drift gate run
- [README Standards](./readme.instructions.md) — project-level documentation, distinct from command help
