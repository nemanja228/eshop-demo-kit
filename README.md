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
   LocalDB (see below); Claude Code, logged into the account that will run the matrix;
   and the personal SSH host alias in `~/.ssh/config` (same setup as the main machine —
   bootstrap verifies it and prints the block to add if missing):

   ```
   Host github-nemanja228
       HostName github.com
       User git
       IdentityFile C:\Users\<you>\.ssh\github-nemanja228
   ```

   Verify with `ssh -T git@github-nemanja228` → "Hi nemanja228!". Clone this kit with
   `git clone git@github-nemanja228:nemanja228/eshop-demo-kit.git`.

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

## Build / test / run (day-to-day reference)

All commands run in the FORK clone (the sibling `eShopOnWeb/` directory), never in this kit.

```powershell
dotnet build eShopOnWeb.sln
dotnet test  eShopOnWeb.sln     # 74/74 green at demo-base; tests need no database
```

Run the apps (LocalDB; each app creates, migrates, and seeds its databases automatically
on first start — start them ONE AT A TIME the first time):

```powershell
cd src\Web       ; dotnet run --launch-profile Web        # storefront  http://localhost:5000  https://localhost:5001
cd src\PublicApi ; dotnet run --launch-profile PublicApi  # API         http://localhost:5098  https://localhost:5099
```

- Admin UI: `/admin` on the Web app; requires PublicApi to be running.
- Logins: `admin@microsoft.com` / `Pass@word1` (Administrators), `demouser@microsoft.com` / `Pass@word1`.
- Don't archive/rename ".NET Bot Black Sweatshirt" during manual checks (health checks assert it).

DB reset between reps (from `src\Web`; run `dotnet tool restore` once first — `dotnet-ef`
is a local tool):

```powershell
dotnet ef database drop -f -c catalogcontext        -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
dotnet ef database drop -f -c appidentitydbcontext  -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
```

The next app start recreates and reseeds both databases. Adding a migration uses the same
`-p`/`-s` shape — see the fork's README, "Updating the database with migrations".

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
