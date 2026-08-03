#Requires -Version 5.1
<#
Dry-run step 1.3: migration mechanics probe + full DB reset rehearsal.

What it does, in order:
  A. Guards: repo present, working tree clean, no eShopOnWeb app processes running.
  B. Migration probe (catalog context): add a DryRunProbe migration with the README's
     documented command shape, apply it, list it as applied, revert the DB to the
     previous migration, remove the probe files, verify the tree is clean again.
     NOTE: the probe is NOT empty. The committed 2021-era model snapshot has drifted
     from what EF 8 computes from today's model, so ANY new migration scaffolds
     unrelated ALTER COLUMN NOT NULL changes plus a data-loss warning. Expected
     baseline noise - every run that adds a migration will see the same thing.
  C. Reset rehearsal: drop BOTH databases (dotnet ef database drop -f per context),
     start the Web app once, verify it auto-migrates + re-seeds (storefront 200 with
     seeded item), stop it.
  D. Prints the canonical reset method; -Record appends it to runs/runs.md.

Run from anywhere: powershell -File .\dryrun-1-3.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoDir = '',
    [switch]$Record
)

$ErrorActionPreference = 'Stop'
function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; exit 1 }
function Ok($msg)   { Write-Host "  OK: $msg" -ForegroundColor Green }
function Info($msg) { Write-Host $msg -ForegroundColor Cyan }

$kitRoot = $PSScriptRoot
if (-not $RepoDir) { $RepoDir = Join-Path (Split-Path $kitRoot -Parent) 'eShopOnWeb' }
$webDir = Join-Path $RepoDir 'src\Web'
$efArgs = @('-c', 'catalogcontext', '-p', '..\Infrastructure\Infrastructure.csproj', '-s', 'Web.csproj')
# Last catalog migration at demo-base; the probe reverts to it before removal.
$prevMigration = '20211231093753_FixShipToAddress'

# --- A. guards ---------------------------------------------------------------
if (-not (Test-Path (Join-Path $RepoDir '.git'))) { Fail "repo not found at $RepoDir" }
$dirty = git -C $RepoDir status --porcelain
if ($dirty) { Fail "working tree is not clean - commit/stash/revert first:`n$($dirty -join "`n")" }
Ok "working tree clean"

$running = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'eShopOnWeb' }
if ($running) { Fail "eShopOnWeb app processes are running (PIDs: $($running.ProcessId -join ', ')). Stop them first." }
Ok "no app processes running"

Push-Location $webDir
try {
    Info "Restoring dotnet local tools (dotnet-ef)..."
    dotnet tool restore | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail "dotnet tool restore failed" }
    Ok "dotnet-ef available"

    # --- B. migration probe ----------------------------------------------------
    Info "B1. Adding probe migration (expect NRT-drift ALTER COLUMNs + data-loss warning - baseline noise)..."
    dotnet ef migrations add DryRunProbe @efArgs -o Data\Migrations
    if ($LASTEXITCODE -ne 0) { Fail "migrations add failed" }
    Ok "probe migration created"

    Info "B2. Applying to the database..."
    dotnet ef database update @efArgs
    if ($LASTEXITCODE -ne 0) { Fail "database update (apply) failed" }
    Ok "probe applied"

    Info "B3. Migration list (probe should show WITHOUT '(Pending)'):"
    dotnet ef migrations list @efArgs | Select-String 'DryRunProbe|FixShipToAddress'

    Info "B4. Reverting database to $prevMigration ..."
    dotnet ef database update $prevMigration @efArgs
    if ($LASTEXITCODE -ne 0) { Fail "database update (revert) failed" }
    Ok "database reverted"

    Info "B5. Removing probe migration files..."
    dotnet ef migrations remove @efArgs
    if ($LASTEXITCODE -ne 0) { Fail "migrations remove failed" }
    # 'migrations remove' regenerates the snapshot with current-tooling formatting, which
    # differs textually from the committed 2021-era file; restore the committed version.
    git -C $RepoDir checkout -- src/Infrastructure/Data/Migrations/CatalogContextModelSnapshot.cs
    $dirty = git -C $RepoDir status --porcelain
    if ($dirty) { Fail "tree not clean after probe removal - clean up by hand:`n$($dirty -join "`n")" }
    Ok "probe removed, tree clean again"

    # --- C. reset rehearsal ------------------------------------------------------
    Info "C1. Dropping both databases..."
    dotnet ef database drop -f -c catalogcontext -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
    if ($LASTEXITCODE -ne 0) { Fail "catalog db drop failed" }
    dotnet ef database drop -f -c appidentitydbcontext -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
    if ($LASTEXITCODE -ne 0) { Fail "identity db drop failed" }
    Ok "both databases dropped"

    Info "C2. Starting Web once to verify auto-migrate + re-seed (takes ~30-60s)..."
    $proc = Start-Process dotnet -ArgumentList 'run', '--launch-profile', 'Web' -WorkingDirectory $webDir -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(120); $seeded = $false
    while ((Get-Date) -lt $deadline) {
        try {
            $r = Invoke-WebRequest -Uri 'http://localhost:5000/' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
            if ($r.StatusCode -eq 200 -and $r.Content -match '\.NET Bot Black Sweatshirt') { $seeded = $true; break }
        } catch { Start-Sleep -Seconds 3 }
    }
    # stop the app (dotnet run spawns a child; kill by command line, not just the parent)
    Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'eShopOnWeb' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    if (-not $seeded) { Fail "storefront did not come back seeded within 120s - investigate before relying on this reset method" }
    Ok "databases recreated + reseeded (storefront 200 with seeded item)"
}
finally { Pop-Location }

$resetMethod = @"
Reset method (between every scored rep), run from src\Web:
  dotnet ef database drop -f -c catalogcontext        -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
  dotnet ef database drop -f -c appidentitydbcontext  -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
(next app start recreates + reseeds both; verified $(Get-Date -Format yyyy-MM-dd))
"@
Info ""
Info "== 1.3 COMPLETE =="
Write-Host $resetMethod

if ($Record) {
    $runsMd = Join-Path $kitRoot 'runs\runs.md'
    Add-Content -Path $runsMd -Value "`n## Reset method (recorded by dryrun-1-3.ps1)`n`n$resetMethod"
    Ok "recorded in runs/runs.md"
}
