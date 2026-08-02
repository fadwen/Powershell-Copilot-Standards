# Workflow Templates

Workflows to copy into a project that consumes these standards. They are templates, not active
workflows: nothing in this folder runs in the standards repository itself.

## sync-copilot-standards.yml

Keeps a consuming project's Copilot instruction files current. Runs weekly, mirrors the three
instruction paths from the standards repository, and opens a pull request when they have drifted.

Without it, instruction files are copied once and then quietly rot. A project can sit for months on
guidance that has since been corrected upstream.

### Install

```powershell
# Along with the standards themselves
./Tools/Install-CopilotStandards.ps1 -ProjectPath "C:\YourProject" -IncludeSyncWorkflow
```

Or copy it by hand to `.github/workflows/sync-copilot-standards.yml` in the target repository.

### Enable the repository setting first

The job needs permission to open pull requests:

**Settings → Actions → General → Workflow permissions →
"Allow GitHub Actions to create and approve pull requests"**

This is a per-repository setting and it is off by default in many organisations. Without it the job
runs, detects drift correctly, and then fails at the final step. Enable it before the first run, or
trigger the workflow manually once to confirm.

### What it touches

| Path | Behaviour |
| --- | --- |
| `.github/copilot-instructions.md` | Overwritten from upstream |
| `.github/instructions/` | Mirrored — upstream deletions are applied |
| `.github/prompts/` | Mirrored — upstream deletions are applied |
| `.github/workflows/` | Never touched, including this workflow itself |
| Everything else | Never touched |

### Mirror, not merge

Local edits to the three mirrored paths are overwritten on the next run. This is deliberate: a copy
that drifts silently is the problem the workflow exists to solve.

If you need a change to those files, make it upstream in the standards repository. If you need
project-specific guidance, put it in a file outside the mirrored paths — a scoped
`*.instructions.md` under a different directory, referenced from your own VS Code settings, survives
every sync.

### Configuration

| Setting | Default | Notes |
| --- | --- | --- |
| `env.STANDARDS_REPO` | `fadwen/Powershell-Copilot-Standards` | The only line to change if you maintain a fork |
| `schedule.cron` | `0 6 * * 1` (Mondays, 06:00 UTC) | Stagger it if several repositories sync at once |
| `branch` | `chore/sync-copilot-standards` | Reused and deleted after merge |

The workflow also responds to `workflow_dispatch`, so you can run it on demand from the Actions tab.
Note that `workflow_dispatch` only appears there once the file is on the default branch.

### Actions it uses

Pinned to majors that declare `node24`, so the workflow does not inherit the Node 20 runtime
deprecation:

- `actions/checkout@v7`
- `peter-evans/create-pull-request@v8`
