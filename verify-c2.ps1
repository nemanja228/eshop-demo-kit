#Requires -Version 5.1
<#
verify-c2.ps1 — unattended C2 (storefront freshness) harness.

Proves whether a catalog change propagates to the storefront under continuous
traffic, replacing the manual 10-second-refresh test. Baseline expectation
(CachedCatalogViewModelService: 30s SLIDING expiration, no invalidation, admin
writes in a separate process): STALE-UNDER-TRAFFIC=True while polled every 10s,
FRESH-AFTER-IDLE=True after a 40s gap.

Phases: ensure apps -> warm (>=3 consecutive polls showing the pre-change
state) -> fire change -> poll every 10s for 90s -> idle 40s -> single poll.
Verdicts: STALE-UNDER-TRAFFIC = old state still shown at t>=60s of continuous
polling; FRESH-AFTER-IDLE = new state shown on the post-idle poll.
Exit 0 iff STALE-UNDER-TRAFFIC -eq -ExpectStale AND FRESH-AFTER-IDLE -eq
-ExpectFresh (both default True = the baseline).

Default change: rename catalog item 3 "Prism White T-Shirt" (first page; NOT
the health-checked ".NET Bot Black Sweatshirt") via PublicApi as admin, and
revert it during cleanup. Custom changes: pass -ChangeCommand {scriptblock}
plus -OldState/-NewState regexes; add -ExpectAbsence when the "new state" is
the item DISAPPEARING (the archive case; -NewState then defaults to -OldState,
and "new state shown" means the regex NO LONGER matches). -ChangeCommand
callers revert their own change.

Examples:
  powershell -File .\verify-c2.ps1 -StopApps                    # baseline
  powershell -File .\verify-c2.ps1 -Label cell-a-rep1 -ExpectStale:$false `
    -OldState 'Roslyn Red Sheet' -ExpectAbsence -ChangeCommand { .\archive.ps1 }

NOTE: this harness must be the ONLY traffic to http://localhost:5000 during a
run. A browser tab refreshing the storefront keeps the sliding cache alive
through the idle phase and corrupts both verdicts.
#>
[CmdletBinding()]
param(
    [string]$RepoDir = '',
    [string]$Label = 'baseline',
    [switch]$StopApps,
    [string]$OldState = '',
    [string]$NewState = '',
    [switch]$ExpectAbsence,
    [scriptblock]$ChangeCommand,
    [bool]$ExpectStale = $true,
    [bool]$ExpectFresh = $true
)

$ErrorActionPreference = 'Stop'

$kitRoot = $PSScriptRoot
if (-not $RepoDir) { $RepoDir = Join-Path (Split-Path $kitRoot -Parent) 'eShopOnWeb' }
$webDir = Join-Path $RepoDir 'src\Web'
$apiDir = Join-Path $RepoDir 'src\PublicApi'
$storeUrl = 'http://localhost:5000/'
# PublicApi redirects http->https; a POST/PUT through that redirect is not
# replayed reliably, so talk to the https endpoint directly.
$apiBase = 'https://localhost:5099/api'
$adminUser = 'admin@microsoft.com'; $adminPass = 'Pass@word1'  # seeded demo creds (fork README)
$defaultItemId = 3
$canonicalName = 'Prism White T-Shirt'
$probeName = 'C2 Probe White T-Shirt'   # disjoint from every seeded name, so old/new regexes cannot overlap

if ($ChangeCommand) {
    if (-not $OldState) { throw '-ChangeCommand requires -OldState (regex for the pre-change state).' }
    if (-not $NewState -and -not $ExpectAbsence) { throw '-ChangeCommand requires -NewState, or -ExpectAbsence for disappearing items.' }
}
if (-not (Test-Path (Join-Path $RepoDir '.git'))) { throw "fork repo not found at $RepoDir" }

$runDir = Join-Path $kitRoot (Join-Path 'runs' $Label)
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$script:logFile = Join-Path $runDir 'c2-log.txt'
Set-Content -Path $script:logFile -Value ("== verify-c2 {0:yyyy-MM-dd HH:mm:ss} label={1} ==" -f (Get-Date), $Label)

function Log { param([string]$Msg, [string]$Color = 'Gray')
    $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $Msg
    Write-Host $line -ForegroundColor $Color
    Add-Content -Path $script:logFile -Value $line
}
function Fail { param([string]$Msg) Log "FAIL: $Msg" 'Red'; exit 1 }

# Polls of :5000 get redirected to the https dev cert. NOTE: in Windows
# PowerShell 5.1 a *scriptblock* ServerCertificateValidationCallback breaks
# every request ("unexpected error on a send") - it must be a compiled
# delegate, hence Add-Type. (Pattern proven in dryrun-1-3.ps1.)
$iwrArgs = @{}
if ($PSVersionTable.PSVersion.Major -ge 6) { $iwrArgs['SkipCertificateCheck'] = $true }
else {
    if (-not ('DemoCertTrust' -as [type])) {
        Add-Type @"
using System.Net;
public static class DemoCertTrust {
    public static void Enable() {
        ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };
    }
}
"@
    }
    [DemoCertTrust]::Enable()
}

# 'dotnet run' spawns the app as an apphost (Web.exe / PublicApi.exe), so sweep
# those too - killing only dotnet.exe leaves orphans holding ports and DLLs.
function Get-EshopProcs {
    Get-CimInstance Win32_Process -Filter "Name='dotnet.exe' OR Name='Web.exe' OR Name='PublicApi.exe'" -ErrorAction SilentlyContinue |
        Where-Object { ($_.CommandLine -match 'eShopOnWeb') -or ($_.ExecutablePath -match 'eShopOnWeb') }
}

function Get-StorefrontHtml {
    try {
        $r = Invoke-WebRequest -Uri $storeUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop @iwrArgs
        if ($r.StatusCode -eq 200) { return [string]$r.Content }
    } catch { }
    return $null
}

# OLD / NEW / BOTH / NEITHER / DOWN. In absence mode "new state shown" means
# the NewState regex no longer matches (the item disappeared).
function Get-ObservedState { param([string]$Html)
    if (-not $Html) { return 'DOWN' }
    $oldSeen = $Html -match $script:OldState
    if ($ExpectAbsence) { $newSeen = -not ($Html -match $script:NewState) }
    else                { $newSeen = $Html -match $script:NewState }
    if ($oldSeen -and $newSeen) { return 'BOTH' }
    if ($oldSeen) { return 'OLD' }
    if ($newSeen) { return 'NEW' }
    return 'NEITHER'
}

function Test-WebUp {
    $h = Get-StorefrontHtml
    return [bool]($h -and $h -match '\.NET Bot Black Sweatshirt')
}
function Test-ApiUp {
    try {
        Invoke-RestMethod -Uri "$apiBase/catalog-items?pageSize=1" -TimeoutSec 15 -ErrorAction Stop @iwrArgs | Out-Null
        return $true
    } catch { return $false }
}

function Get-AdminToken {
    $body = @{ username = $adminUser; password = $adminPass } | ConvertTo-Json
    $resp = Invoke-RestMethod -Method Post -Uri "$apiBase/authenticate" -ContentType 'application/json' -Body $body -TimeoutSec 15 @iwrArgs
    if (-not $resp.result -or -not $resp.token) { Fail "authenticate as $adminUser failed" }
    return $resp.token
}
function Get-CatalogItem { param([int]$Id)
    $resp = Invoke-RestMethod -Uri "$apiBase/catalog-items/$Id" -TimeoutSec 15 @iwrArgs
    return $resp.catalogItem
}
function Set-ItemName { param([int]$Id, [string]$Name, [string]$Token)
    $item = Get-CatalogItem $Id
    if (-not $item) { Fail "catalog item $Id not found" }
    $body = @{
        id = $item.id; catalogBrandId = $item.catalogBrandId; catalogTypeId = $item.catalogTypeId
        description = $item.description; name = $Name; price = $item.price
    } | ConvertTo-Json
    Invoke-RestMethod -Method Put -Uri "$apiBase/catalog-items" -ContentType 'application/json' `
        -Headers @{ Authorization = "Bearer $Token" } -Body $body -TimeoutSec 15 @iwrArgs | Out-Null
}

$script:renameApplied = $false
$script:startedApps = $false
$exitCode = 1
try {
    # --- ensure apps ---------------------------------------------------------
    $webUp = Test-WebUp; $apiUp = Test-ApiUp
    if ($webUp -and $apiUp) {
        Log "Web and PublicApi already running" 'Green'
    } else {
        Log ("apps not fully up (web={0} api={1}); sweeping eShopOnWeb processes..." -f $webUp, $apiUp)
        Get-EshopProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $left = Get-EshopProcs
        if ($left) { Fail "processes survived the sweep: $(($left | ForEach-Object { "$($_.Name) $($_.ProcessId)" }) -join ', ')" }
        # one at a time: Web first migrates+seeds both DBs, avoiding the
        # concurrent first-start migration race.
        Log "starting Web (cold DB can take a while to migrate+seed)..."
        Start-Process dotnet -ArgumentList 'run', '--launch-profile', 'Web' -WorkingDirectory $webDir -WindowStyle Hidden | Out-Null
        $deadline = (Get-Date).AddSeconds(240)
        while (-not (Test-WebUp)) {
            if ((Get-Date) -gt $deadline) { Fail "Web not serving a seeded storefront on $storeUrl within 240s" }
            Start-Sleep -Seconds 3
        }
        Log "Web ready on $storeUrl" 'Green'
        Log "starting PublicApi..."
        Start-Process dotnet -ArgumentList 'run', '--launch-profile', 'PublicApi' -WorkingDirectory $apiDir -WindowStyle Hidden | Out-Null
        $deadline = (Get-Date).AddSeconds(240)
        while (-not (Test-ApiUp)) {
            if ((Get-Date) -gt $deadline) { Fail "PublicApi not answering on $apiBase within 240s" }
            Start-Sleep -Seconds 3
        }
        Log "PublicApi ready on $apiBase" 'Green'
        $script:startedApps = $true
    }

    # --- prepare the change + state predicates -------------------------------
    if (-not $ChangeCommand) {
        $script:token = Get-AdminToken
        $item = Get-CatalogItem $defaultItemId
        if (-not $item) { Fail "catalog item $defaultItemId not found" }
        if ($item.name -eq $probeName) {
            Log "leftover probe name from a crashed run; reverting to '$canonicalName' and idling 40s so the cache lets go of it..." 'Yellow'
            Set-ItemName $defaultItemId $canonicalName $script:token
            Start-Sleep -Seconds 40
            $item = Get-CatalogItem $defaultItemId
        }
        $script:oldName = $item.name
        $script:newName = $probeName
        if (-not $OldState) { $OldState = [regex]::Escape($script:oldName) }
        if (-not $NewState) { $NewState = [regex]::Escape($script:newName) }
    }
    if ($ExpectAbsence -and -not $NewState) { $NewState = $OldState }
    $script:OldState = $OldState; $script:NewState = $NewState

    Log ("config: label={0} expectStale={1} expectFresh={2} absenceMode={3}" -f $Label, $ExpectStale, $ExpectFresh, [bool]$ExpectAbsence)
    Log ("state predicates: OLD='{0}' NEW='{1}'" -f $OldState, $NewState)

    # --- warm phase ----------------------------------------------------------
    # A cold cache entry would make ANY change look fresh (false negative), so
    # require 3 consecutive 10s polls showing the pre-change state: the entry
    # exists and its sliding window is being touched.
    Log "warm phase: polling every 10s until pre-change state seen 3x consecutively..."
    $warmHits = 0; $warmPolls = 0
    while ($warmHits -lt 3) {
        if ($warmPolls -gt 0) { Start-Sleep -Seconds 10 }
        $warmPolls++
        $state = Get-ObservedState (Get-StorefrontHtml)
        if ($state -eq 'OLD' -or $state -eq 'BOTH') { $warmHits++ } else { $warmHits = 0 }
        Log ("warm poll {0}: state={1} ({2}/3)" -f $warmPolls, $state, $warmHits)
        if ($warmPolls -ge 18) { Fail "pre-change state (regex '$OldState') not stable on $storeUrl after $warmPolls polls" }
    }
    Log "cache warm: pre-change state confirmed under traffic" 'Green'

    # --- fire the change -----------------------------------------------------
    if ($ChangeCommand) {
        Log "firing custom -ChangeCommand..."
        & $ChangeCommand
        Log "custom change command completed"
    } else {
        Log ("renaming item {0} '{1}' -> '{2}' via PublicApi PUT..." -f $defaultItemId, $script:oldName, $script:newName)
        Set-ItemName $defaultItemId $script:newName $script:token
        $script:renameApplied = $true
        Log "rename accepted by the API (database now holds the new state)"
    }
    $changeTime = Get-Date

    # --- staleness phase: 90s of continuous 10s polling ----------------------
    Log "staleness phase: polling every 10s for 90s..."
    $lastOldAt = -1; $firstNewAt = -1
    do {
        Start-Sleep -Seconds 10
        $state = Get-ObservedState (Get-StorefrontHtml)
        $t = [int]((Get-Date) - $changeTime).TotalSeconds
        Log ("staleness poll t=+{0}s state={1}" -f $t, $state)
        if ($state -eq 'OLD' -or $state -eq 'BOTH') { $lastOldAt = $t }
        if ($state -eq 'NEW' -and $firstNewAt -lt 0) { $firstNewAt = $t }
    } while ($t -lt 90)
    $staleUnderTraffic = ($lastOldAt -ge 60)

    # --- freshness phase: 40s idle, then one poll ----------------------------
    Log "freshness phase: 40s with NO storefront traffic (keep browsers off $storeUrl)..."
    Start-Sleep -Seconds 40
    $state = Get-ObservedState (Get-StorefrontHtml)
    $t = [int]((Get-Date) - $changeTime).TotalSeconds
    Log ("freshness poll t=+{0}s (after 40s idle): state={1}" -f $t, $state)
    $freshAfterIdle = ($state -eq 'NEW')

    # --- verdicts ------------------------------------------------------------
    $oldNote = if ($lastOldAt -ge 0) { "old state last seen t=+${lastOldAt}s" } else { "old state never seen post-change" }
    $newNote = if ($firstNewAt -ge 0) { "new state first seen under traffic t=+${firstNewAt}s" } else { "new state never seen under traffic" }
    Log ("VERDICT STALE-UNDER-TRAFFIC={0} ({1}; {2}; expected {3})" -f $staleUnderTraffic, $oldNote, $newNote, $ExpectStale) 'Cyan'
    Log ("VERDICT FRESH-AFTER-IDLE={0} (expected {1})" -f $freshAfterIdle, $ExpectFresh) 'Cyan'
    $pass = ($staleUnderTraffic -eq $ExpectStale) -and ($freshAfterIdle -eq $ExpectFresh)
    if ($pass) { Log "RESULT PASS: observed behavior matches expectations" 'Green'; $exitCode = 0 }
    else       { Log "RESULT FAIL: observed behavior does not match expectations" 'Red'; $exitCode = 1 }
}
finally {
    if ($script:renameApplied) {
        try {
            Set-ItemName $defaultItemId $script:oldName $script:token
            Log ("cleanup: reverted item {0} name to '{1}'" -f $defaultItemId, $script:oldName)
        } catch {
            Log "WARNING: failed to revert the rename - item $defaultItemId still named '$($script:newName)': $_" 'Red'
        }
    }
    if ($StopApps) {
        Get-EshopProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 2
        $left = Get-EshopProcs
        if ($left) { Log "WARNING: processes survived -StopApps: $(($left | ForEach-Object { "$($_.Name) $($_.ProcessId)" }) -join ', ')" 'Red' }
        else { Log "cleanup: apps stopped (-StopApps)" }
    } elseif ($script:startedApps) {
        Log "apps started by this run are left running; pass -StopApps to stop them"
    }
    Log ("log written to {0}" -f $script:logFile)
}
exit $exitCode
