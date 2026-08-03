# eshop-demo-kit

Operator kit for the "Plan, Delegate, Verify" internal talk: a controlled experiment
running the same feature task against eShopOnWeb several ways (one-shot vs planned, across
models), producing the talk's scoreboard, artifacts, and replay exercise.

**Spoiler note:** this kit contains the answer key (trap inventory, rubric, FAQ). The
attendee-facing exercise lives in the eShopOnWeb fork, not here.

## New machine setup

1. Prerequisites: git; .NET 8 SDK (`winget install Microsoft.DotNet.SDK.8`); SQL Server
   LocalDB (SQL Server Express or the Visual Studio installer); Claude Code, logged into
   the account that will run the matrix.
2. Clone this repo, then:

   ```powershell
   powershell -File .\bootstrap.ps1
   ```

   The script verifies the toolchain, clones the pinned `nemanja228/eShopOnWeb` fork as a
   SIBLING of this repo (never inside it), checks out the `demo-base` tag, asserts the
   pinned SHA, builds, and runs the baseline test suite. Options: `-ForkUrl`, `-TargetDir`,
   `-SkipBuild`, `-SkipTests`.

3. Read `runbook.md` (phases, fairness rules, capture checklist) before any run.

## Layout

| Path | What |
|------|------|
| `bootstrap.ps1` | Fresh-machine setup + pin assert + baseline build/test |
| `runbook.md` | Phases, matrix design, fairness rules, trap inventory, session hygiene |
| `setup-report.md` | Environment facts + full recon findings (file:line cited) |
| `prompts/` | Frozen at phase 2: task brief, planning instructions, FAQ, rubric |
| `runs/` | Per-rep artifacts and the runs.md log (phase 4) |

## Non-negotiables

- The fork clone stays OUTSIDE this repo's tree (bootstrap enforces; Claude Code loads
  CLAUDE.md from ancestor directories, and this kit is the answer key).
- Nothing from the trap inventory ever enters the fork's CLAUDE.md or the task brief.
- Every scored run follows runbook.md's fairness rules; scoring is against the
  pre-registered rubric only.
