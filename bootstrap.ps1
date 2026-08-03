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
    # Default assumes the personal SSH host alias from ~/.ssh/config (same setup on all
    # machines). Pass a plain URL via -ForkUrl if a machine authenticates differently.
    [string]$ForkUrl   = 'git@github-nemanja228:nemanja228/eShopOnWeb.git',
    [string]$TargetDir = '',
    [string]$PinnedTag = 'demo-base',
    # demo-base = pinned upstream HEAD (4da8212) + the reviewed CLAUDE.md commit.
    [string]$PinnedSha = '555ce7179aa2c35a391b98676e68af12957c3332',
    [switch]$SkipBuild,
    [switch]$SkipTests,
    # Install missing prerequisites (.NET 8 SDK via winget, SQL LocalDB via the SQL 2019
    # Express media downloader). Machine-global installs; UAC prompts will appear.
    [switch]$InstallPrereqs
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

# SSH auth preflight: verify the fork URL's host authenticates before anything clones,
# so a missing alias fails loudly here instead of as a cryptic git error later.
if ($ForkUrl -match '^git@([^:]+):') {
    $sshHost = $Matches[1]
    $sshOut = & { $ErrorActionPreference = 'Continue'; ssh -o StrictHostKeyChecking=accept-new -T "git@$sshHost" 2>&1 } | Out-String
    if ($sshOut -match 'successfully authenticated') {
        Ok ("SSH auth to $sshHost works (" + ($sshOut -split "`r?`n")[0].Trim() + ")")
    } else {
        Fail ("SSH auth to '$sshHost' failed:`n$($sshOut.Trim())`n" +
              "This kit assumes the personal SSH host alias in ~/.ssh/config:`n" +
              "  Host github-nemanja228`n" +
              "      HostName github.com`n" +
              "      User git`n" +
              "      IdentityFile C:\Users\<you>\.ssh\github-nemanja228`n" +
              "Add it (and the key), or pass -ForkUrl with a URL that works on this machine.")
    }
}

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Test-Sdk8 {
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $false }
    return [bool](@(dotnet --list-sdks) | Where-Object { $_ -match '^8\.0\.' })
}
function Test-LocalDb {
    if (Get-Command sqllocaldb -ErrorAction SilentlyContinue) { return $true }
    # fresh installs may not be on this process's PATH yet
    $exe = Get-ChildItem 'C:\Program Files\Microsoft SQL Server' -Filter sqllocaldb.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) { $env:Path += ';' + $exe.DirectoryName; return $true }
    return $false
}

if (-not (Test-Sdk8)) {
    if ($InstallPrereqs) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Fail "winget not available; install the .NET 8 SDK manually (see kit README)." }
        Info "Installing .NET 8 SDK via winget (a UAC prompt may appear)..."
        winget install Microsoft.DotNet.SDK.8 --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { Fail "winget install of the .NET 8 SDK failed (exit $LASTEXITCODE)." }
        Refresh-Path
        if (-not (Test-Sdk8)) { Fail ".NET 8 SDK installed but not detected in this process; open a NEW terminal and re-run bootstrap." }
        Ok ".NET 8 SDK installed"
    } else {
        Fail ".NET 8 SDK required (global.json pins 8.0.x; other majors will NOT be used). Re-run with -InstallPrereqs, or: winget install Microsoft.DotNet.SDK.8"
    }
} else { Ok ".NET 8 SDK present" }

if (-not (Test-LocalDb)) {
    if ($InstallPrereqs) {
        Info "Installing SQL Server LocalDB (SQL 2019 Express media downloader; a UAC prompt will appear)..."
        $tmp = Join-Path $env:TEMP 'eshop-demo-localdb'
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $ssei = Join-Path $tmp 'SQL2019-SSEI-Expr.exe'
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=866658' -OutFile $ssei
        Start-Process -FilePath $ssei -ArgumentList '/Action=Download', '/MediaType=LocalDB', "/MediaPath=$tmp", '/Quiet' -Wait
        $msi = Get-ChildItem $tmp -Filter 'SqlLocalDB.msi' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $msi) { Fail "LocalDB media download produced no SqlLocalDB.msi; install manually (kit README, 'Installing LocalDB')." }
        try {
            Start-Process msiexec.exe -ArgumentList "/i `"$($msi.FullName)`" IACCEPTSQLLOCALDBLICENSETERMS=YES /qn /norestart" -Verb RunAs -Wait
        } catch { Fail "LocalDB MSI install was cancelled or failed: $($_.Exception.Message)" }
        Refresh-Path
        if (-not (Test-LocalDb)) { Fail "LocalDB installed but not detected in this process; open a NEW terminal and re-run bootstrap." }
        Ok "LocalDB installed"
    } else {
        Fail "SQL Server LocalDB not found (default DB mode needs it; in-memory mode skips EF migrations, which this demo must exercise). Re-run with -InstallPrereqs, or install manually (kit README, 'Installing LocalDB')."
    }
} else { Ok "LocalDB present" }
$null = sqllocaldb info 2>&1

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
