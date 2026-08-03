#Requires -Version 5.1
<#
Bootstrap the eShopOnWeb demo environment on a fresh machine.

Usage (from the cloned kit repo):
    powershell -File .\bootstrap.ps1
    pwsh -File .\bootstrap.ps1 -ForkUrl git@github.com:nemanja228/eShopOnWeb.git

Clones the pinned fork OUTSIDE the kit tree (context isolation for agent runs),
verifies the toolchain, builds, and runs the baseline test suite.
#>
[CmdletBinding()]
param(
    [string]$ForkUrl   = 'git@github.com:nemanja228/eShopOnWeb.git',
    [string]$TargetDir = '',
    [string]$PinnedTag = 'demo-base',
    # Set to the demo-base commit SHA once the tag exists; 'TBD' skips the assert with a warning.
    [string]$PinnedSha = 'TBD',
    [switch]$SkipBuild,
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }
function Ok($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Info($msg) { Write-Host $msg -ForegroundColor Cyan }

$kitRoot = $PSScriptRoot
if (-not $TargetDir) { $TargetDir = Join-Path (Split-Path $kitRoot -Parent) 'eShopOnWeb' }
$resolvedTarget = [System.IO.Path]::GetFullPath($TargetDir)

Info "== eShopOnWeb demo bootstrap =="
Info "Kit:    $kitRoot"
Info "Target: $resolvedTarget"

# --- guards ------------------------------------------------------------------
if ($resolvedTarget.StartsWith([System.IO.Path]::GetFullPath($kitRoot), [System.StringComparison]::OrdinalIgnoreCase)) {
    Fail "Target dir is inside the kit repo. Runs must live OUTSIDE the kit tree (the kit contains the answer key)."
}

# Contamination check: Claude Code loads CLAUDE.md from ancestor directories of a
# session's cwd, so nothing above the run directory may carry one.
$probe = Split-Path $resolvedTarget -Parent
while ($probe) {
    if (Test-Path (Join-Path $probe 'CLAUDE.md')) {
        Fail "CLAUDE.md found at '$probe', an ancestor of the run directory. It would leak into every run session. Remove or relocate it."
    }
    $parent = Split-Path $probe -Parent
    if (-not $parent -or $parent -eq $probe) { break }
    $probe = $parent
}
Ok "no ancestor CLAUDE.md above the run directory"

# --- prerequisites -------------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Fail "git not found on PATH." }
Ok "git present"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Fail ".NET SDK not found. Install: winget install Microsoft.DotNet.SDK.8"
}
$sdks = @(dotnet --list-sdks)
if (-not ($sdks | Where-Object { $_ -match '^8\.0\.' })) {
    Fail (".NET 8 SDK required (global.json pins 8.0.x, rollForward=latestFeature; other majors will NOT be used)." +
          " Install: winget install Microsoft.DotNet.SDK.8`nInstalled SDKs:`n" + ($sdks -join "`n"))
}
Ok ".NET 8 SDK present"

if (-not (Get-Command sqllocaldb -ErrorAction SilentlyContinue)) {
    Fail "SQL Server LocalDB not found. The default DB mode needs it (in-memory mode skips EF migrations entirely, which this demo must exercise). Install SQL Server Express LocalDB, or via the Visual Studio installer."
}
$null = sqllocaldb info 2>&1
Ok "LocalDB present"

# --- clone / pin ---------------------------------------------------------------
if (-not (Test-Path (Join-Path $resolvedTarget '.git'))) {
    Info "Cloning $ForkUrl ..."
    git clone $ForkUrl $resolvedTarget
    if ($LASTEXITCODE -ne 0) { Fail "clone failed (does the fork exist / does this machine have push-capable auth for it?)" }
} else {
    Info "Repo already present; fetching tags..."
    git -C $resolvedTarget fetch --all --tags
    if ($LASTEXITCODE -ne 0) { Fail "fetch failed" }
}

git -C $resolvedTarget checkout $PinnedTag
if ($LASTEXITCODE -ne 0) { Fail "checkout of tag '$PinnedTag' failed. Has demo-base been created and pushed?" }

$head = (git -C $resolvedTarget rev-parse HEAD).Trim()
if ($PinnedSha -eq 'TBD') {
    Write-Host "WARN: PinnedSha is TBD, SHA assert skipped. Pin it in bootstrap.ps1 once demo-base exists. HEAD=$head" -ForegroundColor Yellow
} elseif ($head -ne $PinnedSha) {
    Fail "HEAD $head does not match pinned SHA $PinnedSha. Refusing to continue."
} else {
    Ok "pinned at $head"
}

# --- build / baseline tests ----------------------------------------------------
$sln = Join-Path $resolvedTarget 'eShopOnWeb.sln'
if (-not $SkipBuild) {
    Info "Restoring + building eShopOnWeb.sln ..."
    dotnet build $sln -c Debug
    if ($LASTEXITCODE -ne 0) { Fail "build failed" }
    Ok "build succeeded"
}
if (-not $SkipTests) {
    Info "Running baseline test suite (uses in-memory DB, no LocalDB needed for tests)..."
    if ($SkipBuild) { dotnet test $sln -c Debug } else { dotnet test $sln -c Debug --no-build }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARN: test run returned nonzero. Record the exact baseline failures in setup-report.md BEFORE any demo run; do not fix them." -ForegroundColor Yellow
    } else {
        Ok "baseline tests green"
    }
}

Info ""
Info "== Next steps =="
Info "1. First app run creates + seeds the LocalDB databases automatically:"
Info "     cd $resolvedTarget\src\Web       ; dotnet run    (storefront)"
Info "     cd $resolvedTarget\src\PublicApi ; dotnet run    (API; BlazorAdmin is hosted by Web at /admin)"
Info "   Logins: admin@microsoft.com / Pass@word1   demouser@microsoft.com / Pass@word1"
Info "   NOTE: start Web and PublicApi one at a time on first run (both auto-migrate + seed; concurrent first start can race)."
Info "2. Matrix runs: per-rep branches in the fork clone, per runbook.md. The kit stays out of that tree."
Info "3. Before any scored run: check no ~/.claude global CLAUDE.md interferes (see runbook.md, Fairness)."
