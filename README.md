# eshop-demo-kit

Operator kit for the "Plan, Delegate, Verify" internal talk: a controlled experiment
running the same feature task against eShopOnWeb several ways (one-shot vs planned, across
models), producing the talk's scoreboard, artifacts, and replay exercise.

**Spoiler note:** this kit contains the answer key (trap inventory, rubric, FAQ). The
attendee-facing exercise lives in the eShopOnWeb fork, not here.

## Who reads what (do not mix these up)

- **Every file in this kit is for the human operator.** The runbook, this README,
  dryrun-checklist, setup-report, rubric, FAQ — none of it is ever given to an agent.
- **Agents receive exactly three texts**, pasted verbatim as chat messages into sessions
  started in the FORK clone directory (never the kit directory):
  1. `prompts/task-brief.md` — one-shot cells: this is the entire prompt.
  2. `prompts/planning-instructions.md` — planned cells, session 1.
  3. `prompts/implement-task-template.md` — planned cells, one session per task,
     with `{N}` substituted.
- Never point an agent at a kit file path, and never start a session in the kit
  directory.

## New machine setup

1. Prerequisites: git; .NET 8 SDK (`winget install Microsoft.DotNet.SDK.8`); SQL Server
   LocalDB (see below); Claude Code, logged into the account that will run the matrix.

   **Installing LocalDB** (it is a feature of SQL Server Express, not a standalone
   winget package):
   - If Visual Studio is installed: VS Installer → Modify → Individual components →
     check "SQL Server Express LocalDB". Fastest route.
   - Otherwise: `winget install Microsoft.SQLServer.2022.Express`, run the installer,
     choose **Download Media → LocalDB**, then run the downloaded `SqlLocalDB.msi`
     (small, installs only LocalDB). Installing full Express also works but is more
     than needed.
   - Verify: `sqllocaldb info` lists `MSSQLLocalDB`.
2. Clone this repo, then:

   ```powershell
   powershell -File .\bootstrap.ps1 -InstallPrereqs
   ```

   `-InstallPrereqs` installs a missing .NET 8 SDK (winget) and missing LocalDB (SQL 2019
   Express media downloader → SqlLocalDB.msi) — machine-global, expect UAC prompts. The
   script then verifies the toolchain, clones the pinned `nemanja228/eShopOnWeb` fork as a
   SIBLING of this repo (never inside it), checks out the `demo-base` tag, asserts the
   pinned SHA, builds, and runs the baseline test suite. Other options: `-ForkUrl`,
   `-TargetDir`, `-SkipBuild`, `-SkipTests`. If an install step succeeds but isn't
   detected, open a new terminal and re-run (PATH refresh).

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
