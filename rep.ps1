#Requires -Version 5.1
<#
rep.ps1 — the operator's wrapper around ONE scored rep of the demo matrix.

It automates everything AROUND a run and nothing inside it: it never launches,
wraps, or answers a Claude Code session. The operator runs the session by hand,
in the FORK clone, between 'start' and 'finish'. Fairness rules (runbook.md) are
binding; this tool only enforces the mechanical ones (clean tree, no orphans,
fresh branch from demo-base, per-rep auto-memory wipe).

Two subcommands, both take -Cell <a|b|c|d|e|f|x> and -Rep <n>. Cell 'x' is a
throwaway used only to dry-test this script; it is never scored.

  rep.ps1 start  -Cell a -Rep 1
    Guards (fork tree clean, no app processes, auto-memory dir absent), fetches,
    branches cell-<cell>-rep<n> from the demo-base tag and checks it out, writes
    runs/<branch>/meta.json, and prints the operator's launch card (model to
    select, prompt file to paste, permission mode, fairness reminders).

  rep.ps1 finish -Cell a -Rep 1
    Captures the diff/commits (+ plan/ for planned cells) into runs/<branch>/,
    records the rep row in runs/runs.md (prompts for tokens/FAQ/outcome, or takes
    them from -Tokens/-Faq/-Note/-ModelId), pushes the branch, then resets to
    demo-base + drops both LocalDB databases + wipes any fork auto-memory so the
    next rep starts from zero.

Params:
  -RepoDir     Fork clone (default: sibling eShopOnWeb).
  -Tokens/-Faq/-Note/-ModelId  (finish) supply the interactive readouts non-
               interactively; any omitted value is asked for with Read-Host.
  -SkipDbReset (finish) skip the two 'dotnet ef database drop' calls (e.g. when
               resetting the database by hand). The tree reset still runs.

Run from anywhere: powershell -File .\rep.ps1 start -Cell a -Rep 1
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('start', 'finish')]
    [string]$Command,

    [Parameter(Mandatory = $true)]
    [ValidateSet('a', 'b', 'c', 'd', 'e', 'f', 'x')]
    [string]$Cell,

    [Parameter(Mandatory = $true)]
    [int]$Rep,

    [string]$RepoDir = '',

    # finish-only readout overrides (any omitted value falls back to Read-Host)
    [string]$Tokens,
    [string]$Faq,
    [string]$Note,
    [string]$ModelId,
    [switch]$SkipDbReset
)

$ErrorActionPreference = 'Stop'

function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }
function Ok($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Warn($msg) { Write-Host $msg -ForegroundColor Yellow }

$kitRoot = $PSScriptRoot
if (-not $RepoDir) { $RepoDir = Join-Path (Split-Path $kitRoot -Parent) 'eShopOnWeb' }
$webDir  = Join-Path $RepoDir 'src\Web'
$branch  = "cell-$Cell-rep$Rep"
$runDir  = Join-Path $kitRoot (Join-Path 'runs' $branch)
$metaPath = Join-Path $runDir 'meta.json'
$runsMd  = Join-Path $kitRoot 'runs\runs.md'

# --- the cell matrix (from runbook.md "The experiment") ----------------------
# One-shot cells print Model + Prompt. Planned cells (C/D/E) run a planning
# session first (PlanModel + planning-instructions.md) then one implement
# session per task (ImplModel + implement-task-template.md, {N} substituted).
$matrix = @{
    a = @{ Mode = 'one-shot'; Model = 'Sonnet'; Prompt = 'prompts/task-brief.md';            Reps = '3';   Note = 'scoreboard' }
    b = @{ Mode = 'one-shot'; Model = 'Opus';   Prompt = 'prompts/task-brief.md';            Reps = '3';   Note = 'scoreboard' }
    c = @{ Mode = 'planned';  PlanModel = 'Opus';   ImplModel = 'Sonnet'; PlanPrompt = 'prompts/planning-instructions.md'; ImplPrompt = 'prompts/implement-task-template.md'; Reps = '2-3'; Note = 'scoreboard' }
    d = @{ Mode = 'planned';  PlanModel = 'Sonnet'; ImplModel = 'Sonnet'; PlanPrompt = 'prompts/planning-instructions.md'; ImplPrompt = 'prompts/implement-task-template.md'; Reps = '1-2'; Note = 'backup slide' }
    e = @{ Mode = 'planned';  PlanModel = 'Opus';   ImplModel = 'Opus';   PlanPrompt = 'prompts/planning-instructions.md'; ImplPrompt = 'prompts/implement-task-template.md'; Reps = '2';   Note = 'execution-model control (backup slide)' }
    f = @{ Mode = 'one-shot'; Model = 'Fable';  Prompt = 'prompts/task-brief.md';            Reps = '1-2'; Note = 'Q&A ammo only, never the main scoreboard' }
    x = @{ Mode = 'one-shot'; Model = '(test)'; Prompt = 'prompts/task-brief.md';            Reps = '0';   Note = 'THROWAWAY TEST CELL - not scored; only exercises rep.ps1' }
}
$cfg = $matrix[$Cell]
if ($cfg.Mode -eq 'one-shot') { $modelLabel = $cfg.Model }
else { $modelLabel = "plan=$($cfg.PlanModel) impl=$($cfg.ImplModel)" }

# 'dotnet run' spawns the app as an apphost (Web.exe / PublicApi.exe), so sweep
# those too - killing only dotnet.exe leaves orphans that hold ports and lock
# DLLs. (Pattern proven in dryrun-1-3.ps1; do not reinvent.)
function Get-EshopProcs {
    Get-CimInstance Win32_Process -Filter "Name='dotnet.exe' OR Name='Web.exe' OR Name='PublicApi.exe'" -ErrorAction SilentlyContinue |
        Where-Object { ($_.CommandLine -match 'eShopOnWeb') -or ($_.ExecutablePath -match 'eShopOnWeb') }
}

# Run 'git -C <fork> <args>' for its side effect, echoing git's real output. git
# writes normal status ("Switched to a new branch", push details, detached-HEAD
# advice) to stderr; in PS 5.1, capturing that stderr through the pipeline (2>&1
# or 2>file) under the script's 'Stop' wraps it as a terminating NativeCommandError
# and renders it as noise. Start-Process isolates the child so both streams stay
# RAW, and gives a real exit code (surfaced via $LASTEXITCODE).
function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $all = @('-C', $RepoDir) + $GitArgs
    $argLine = ($all | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }) -join ' '
    $outF = [System.IO.Path]::GetTempFileName()
    $errF = [System.IO.Path]::GetTempFileName()
    try {
        $p = Start-Process -FilePath 'git' -ArgumentList $argLine -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $outF -RedirectStandardError $errF
        Get-Content -LiteralPath $outF -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
        Get-Content -LiteralPath $errF -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
        $global:LASTEXITCODE = $p.ExitCode
    } finally {
        Remove-Item -LiteralPath $outF, $errF -Force -ErrorAction SilentlyContinue
    }
}

# Write UTF-8 WITHOUT a BOM. PS 5.1 'Set-Content -Encoding UTF8' emits a BOM, which
# dirties tracked files (runs.md) and corrupts patch artifacts. WriteAllLines uses
# CRLF, which core.autocrlf normalizes back to the repo's LF on commit.
function Write-Text {
    param([string]$Path, $Content)
    $enc = New-Object System.Text.UTF8Encoding($false)
    if ($null -eq $Content) { $Content = '' }
    if ($Content -is [System.Array]) { [System.IO.File]::WriteAllLines($Path, [string[]]$Content, $enc) }
    else { [System.IO.File]::WriteAllText($Path, [string]$Content, $enc) }
}

# Claude Code stores per-project memory under ~/.claude/projects/<slug>/memory.
# The slug is the project path with the drive colon and every separator replaced
# by '-'. VERIFIED against THIS kit: 'E:\code\eshop-demo\eshop-demo-kit' ->
# 'E--code-eshop-demo-eshop-demo-kit' (the on-disk slug in ~/.claude/projects).
# Windows path matching is case-insensitive, so Test-Path resolves the fork's
# memory dir even if Claude Code lowercases the slug.
function Get-MemoryDir {
    $forkFull = (Resolve-Path -LiteralPath $RepoDir).Path.TrimEnd('\')
    $slug = $forkFull -replace '[:\\/]', '-'
    return (Join-Path $env:USERPROFILE (Join-Path '.claude\projects' (Join-Path $slug 'memory')))
}

function Assert-ForkRepo {
    if (-not (Test-Path (Join-Path $RepoDir '.git'))) { Fail "fork repo not found at $RepoDir (bootstrap.ps1 clones it as a sibling of the kit)" }
}
function Assert-CleanTree {
    $dirty = git -C $RepoDir status --porcelain
    if ($dirty) { Fail "fork working tree is not clean - commit/stash/reset it first:`n$($dirty -join "`n")" }
    Ok 'fork working tree clean'
}
function Assert-NoAppProcs {
    $running = Get-EshopProcs
    if ($running) { Fail "eShopOnWeb app processes are running: $(($running | ForEach-Object { "$($_.Name) $($_.ProcessId)" }) -join ', '). Stop them first." }
    Ok 'no app processes running'
}

# ============================================================================
# start
# ============================================================================
function Invoke-Start {
    Assert-ForkRepo
    Info "== rep.ps1 start : cell $Cell rep $Rep ($modelLabel, $($cfg.Mode)) =="
    if ($Cell -eq 'x') { Warn 'cell x is the throwaway test cell - this rep will never be scored.' }

    # 1. guards
    Assert-CleanTree
    Assert-NoAppProcs

    # fairness rule 9: an auto-memory dir from an earlier fork session would let
    # this rep silently recall what a prior rep learned. Offer to delete it.
    $memDir = Get-MemoryDir
    if (Test-Path -LiteralPath $memDir) {
        Warn "auto-memory directory exists for the fork: $memDir"
        Warn 'A scored rep must not inherit memory from an earlier rep (fairness rule 9).'
        $ans = Read-Host 'Delete it now? [y/N]'
        if ($ans -match '^(y|yes)$') {
            Remove-Item -LiteralPath $memDir -Recurse -Force
            Ok 'auto-memory directory deleted'
        } else {
            Fail 'refusing to start a scored rep with an existing auto-memory directory; delete it and re-run.'
        }
    } else {
        Ok 'no fork auto-memory directory (rep independence intact)'
    }

    # 2. fetch + fresh branch from the demo-base tag
    if (git -C $RepoDir branch --list $branch) { Fail "branch '$branch' already exists in the fork - a rep may not be started twice. Delete it or pick another rep number." }
    Info 'fetching origin...'
    Invoke-Git fetch --prune
    if ($LASTEXITCODE -ne 0) { Fail 'git fetch failed' }
    if (-not (git -C $RepoDir tag --list demo-base)) { Fail "the 'demo-base' tag is missing from the fork - bootstrap.ps1 pins it." }
    Invoke-Git checkout -b $branch demo-base
    if ($LASTEXITCODE -ne 0) { Fail "could not create/checkout branch '$branch' from demo-base" }
    $baseSha = (git -C $RepoDir rev-parse demo-base).Trim()
    Ok "branch '$branch' created from demo-base ($($baseSha.Substring(0,10))) and checked out"

    # 3. meta.json
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $meta = [ordered]@{
        cell           = $Cell
        rep            = $Rep
        branch         = $branch
        mode           = $cfg.Mode
        model          = $modelLabel
        promptFile     = if ($cfg.Mode -eq 'one-shot') { $cfg.Prompt } else { $cfg.PlanPrompt }
        permissionMode = 'acceptEdits'
        forkDir        = (Resolve-Path -LiteralPath $RepoDir).Path
        demoBaseSha    = $baseSha
        startedAt      = (Get-Date).ToString('o')
    }
    Write-Text $metaPath ($meta | ConvertTo-Json)
    Ok "wrote $metaPath"

    # 4. launch card
    Write-Host ''
    Write-Host '======================== LAUNCH CARD ========================' -ForegroundColor White
    Write-Host ("  Cell/rep      : {0} rep {1}   (branch {2})" -f $Cell, $Rep, $branch)
    Write-Host ("  Mode          : {0}" -f $cfg.Mode)
    Write-Host ("  Run the session IN THE FORK, not the kit:")
    Write-Host ("                  {0}" -f (Resolve-Path -LiteralPath $RepoDir).Path) -ForegroundColor White
    Write-Host ("  Permission    : acceptEdits") -ForegroundColor White
    if ($cfg.Mode -eq 'one-shot') {
        Write-Host ("  Model         : select {0} in Claude Code" -f $cfg.Model) -ForegroundColor White
        Write-Host ("  Prompt        : paste VERBATIM as the only message:") -ForegroundColor White
        Write-Host ("                  {0}" -f (Join-Path $kitRoot ($cfg.Prompt -replace '/', '\'))) -ForegroundColor White
    } else {
        Write-Host ("  Session 1 (plan): select {0}; paste VERBATIM:" -f $cfg.PlanModel) -ForegroundColor White
        Write-Host ("                    {0}" -f (Join-Path $kitRoot ($cfg.PlanPrompt -replace '/', '\'))) -ForegroundColor White
        Write-Host ("  Then per task   : NEW session, select {0}; paste {1}" -f $cfg.ImplModel, $cfg.ImplPrompt) -ForegroundColor White
        Write-Host ("                    with {N} substituted (one session per plan/tasklist.md item)") -ForegroundColor White
    }
    Write-Host ''
    Write-Host '  Fairness reminders (runbook.md):' -ForegroundColor White
    Write-Host '   - Answer questions ONLY from prompts/faq-answers.md, verbatim. Never'
    Write-Host '     volunteer anything. Log every question asked (finish will prompt).'
    Write-Host '   - No nudges, no retries. The run ends when the agent declares done.'
    Write-Host '   - At the end: capture a /context screenshot and the cost/token readout,'
    Write-Host '     and note the exact model ID shown for the session.'
    Write-Host '=============================================================' -ForegroundColor White
    Write-Host ''
    Write-Host ("When the session(s) finish, run:  powershell -File .\rep.ps1 finish -Cell $Cell -Rep $Rep") -ForegroundColor Cyan
}

# ============================================================================
# finish
# ============================================================================
function Invoke-Finish {
    Assert-ForkRepo
    Info "== rep.ps1 finish : cell $Cell rep $Rep ($modelLabel, $($cfg.Mode)) =="
    if (-not (Test-Path -LiteralPath $metaPath)) { Fail "no meta.json at $metaPath - was 'start -Cell $Cell -Rep $Rep' run?" }
    $meta = Get-Content -LiteralPath $metaPath -Raw | ConvertFrom-Json

    # ensure the rep branch is the one checked out (capture reads the working tree)
    if (-not (git -C $RepoDir branch --list $branch)) { Fail "branch '$branch' not found in the fork" }
    $cur = (git -C $RepoDir rev-parse --abbrev-ref HEAD).Trim()
    if ($cur -ne $branch) {
        $dirty = git -C $RepoDir status --porcelain
        if ($dirty) { Fail "the fork is on '$cur' with uncommitted changes; can't switch to '$branch'. Resolve by hand." }
        Invoke-Git checkout $branch
        if ($LASTEXITCODE -ne 0) { Fail "could not check out '$branch'" }
        Ok "checked out '$branch'"
    }

    # 1. capture artifacts (diff = working tree vs demo-base, so it includes any
    #    uncommitted work the agent left behind)
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    Write-Text (Join-Path $runDir 'diff.patch') (git -C $RepoDir diff demo-base)
    Write-Text (Join-Path $runDir 'diff.stat')  (git -C $RepoDir diff --stat demo-base)
    Write-Text (Join-Path $runDir 'commits.txt') (git -C $RepoDir log --oneline --no-decorate demo-base..HEAD)
    $commitCount = @(git -C $RepoDir rev-list --count demo-base..HEAD)[0]
    Ok "captured diff.patch, diff.stat, commits.txt ($commitCount commit(s))"
    if ($cfg.Mode -eq 'planned') {
        foreach ($f in 'spec.md', 'tasklist.md') {
            $src = Join-Path $RepoDir (Join-Path 'plan' $f)
            if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $runDir $f) -Force; Ok "copied plan/$f" }
            else { Warn "planned cell but plan/$f not present in the fork" }
        }
    }

    # 2. interactive readouts (params override the prompts) + duration
    if (-not $PSBoundParameters.ContainsKey('Tokens'))  { $Tokens  = Read-Host 'Tokens / cost readout (from /context or the cost line)' }
    if (-not $PSBoundParameters.ContainsKey('ModelId')) { $ModelId = Read-Host "Exact model ID(s) for the session(s) (blank = use '$modelLabel')" }
    if (-not $PSBoundParameters.ContainsKey('Faq'))     { $Faq     = Read-Host 'FAQ questions asked (paraphrase; blank = none)' }
    if (-not $PSBoundParameters.ContainsKey('Note'))    { $Note    = Read-Host 'One-line outcome note' }
    if (-not $ModelId) { $ModelId = $modelLabel }
    if (-not $Faq)     { $Faq = 'none' }

    $started = [datetime]::Parse($meta.startedAt)
    $ts = (Get-Date) - $started
    $dur = '{0:00}:{1:00}:{2:00}' -f [int]$ts.TotalHours, $ts.Minutes, $ts.Seconds

    # 3. append the rep row to runs/runs.md (after the last row of the run-log table)
    $date = Get-Date -Format 'yyyy-MM-dd'
    $cells = @($date, $Cell, $Rep, $branch, $ModelId, $dur, $Tokens, $Faq, $Note) | ForEach-Object { ([string]$_).Replace('|', '\|').Replace("`n", ' ').Trim() }
    $row = '| ' + ($cells -join ' | ') + ' |'
    Add-RunsRow -RunsMd $runsMd -Row $row
    Ok 'appended rep row to runs/runs.md'
    Write-Host "     $row" -ForegroundColor Gray

    # 4. push the branch (audit trail)
    Info "pushing $branch to origin..."
    Invoke-Git push -u origin $branch
    if ($LASTEXITCODE -ne 0) { Warn "git push failed - push '$branch' by hand before relying on the audit trail." }
    else { Ok "pushed origin/$branch" }

    # 5. reset for the next rep
    Info 'resetting fork to demo-base (detached) + cleaning working tree...'
    Invoke-Git -c advice.detachedHead=false checkout -f demo-base
    if ($LASTEXITCODE -ne 0) { Fail 'could not check out demo-base for reset' }
    Invoke-Git clean -fd
    Ok 'fork reset to demo-base, tree clean'

    if ($SkipDbReset) {
        Warn 'skipping the LocalDB reset (-SkipDbReset). Drop both databases by hand before the next rep.'
    } else {
        Info 'dropping both LocalDB databases (next app start recreates + reseeds)...'
        Push-Location $webDir
        try {
            dotnet tool restore | Out-Null
            dotnet ef database drop -f -c catalogcontext -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
            $c1 = $LASTEXITCODE
            dotnet ef database drop -f -c appidentitydbcontext -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
            $c2 = $LASTEXITCODE
            if ($c1 -ne 0 -or $c2 -ne 0) { Warn "a database drop returned non-zero (catalog=$c1 identity=$c2) - reset the DBs by hand before the next rep." }
            else { Ok 'both databases dropped' }
        } finally { Pop-Location }
    }

    # auto-memory may have reappeared during the session - wipe it (fairness rule 9)
    $memDir = Get-MemoryDir
    if (Test-Path -LiteralPath $memDir) {
        Remove-Item -LiteralPath $memDir -Recurse -Force
        Ok "deleted fork auto-memory that reappeared: $memDir"
    } else {
        Ok 'no fork auto-memory to clear'
    }

    $left = Get-EshopProcs
    if ($left) { Warn "app processes survived: $(($left | ForEach-Object { "$($_.Name) $($_.ProcessId)" }) -join ', ') - stop them before the next rep." }
    else { Ok 'no app processes running' }

    Write-Host ''
    Ok "rep $branch complete: artifacts in runs/$branch, row logged, branch pushed, state reset."
    Info "Next: powershell -File .\rep.ps1 start -Cell <cell> -Rep <n>"
}

# Insert a row into the run-log table of runs.md, right after its last existing
# row (handles the empty-table case: header + separator, no data rows yet).
function Add-RunsRow {
    param([string]$RunsMd, [string]$Row)
    if (-not (Test-Path -LiteralPath $RunsMd)) { throw "runs.md not found at $RunsMd" }
    $lines = @(Get-Content -LiteralPath $RunsMd)
    $headerIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\|\s*date\s*\|\s*cell\s*\|\s*rep\s*\|') { $headerIdx = $i; break }
    }
    if ($headerIdx -lt 0) { throw 'runs.md: could not find the run-log table header row' }
    $insertAt = $headerIdx + 2   # skip the |---| separator
    while ($insertAt -lt $lines.Count -and $lines[$insertAt].TrimStart().StartsWith('|')) { $insertAt++ }
    $out = @()
    if ($insertAt -gt 0) { $out += $lines[0..($insertAt - 1)] }
    $out += $Row
    if ($insertAt -lt $lines.Count) { $out += $lines[$insertAt..($lines.Count - 1)] }
    Write-Text $RunsMd $out
}

switch ($Command) {
    'start'  { Invoke-Start }
    'finish' { Invoke-Finish }
}
