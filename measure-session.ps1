#Requires -Version 5.1
<#
Sum token usage + duration for Claude Code session transcripts (the authoritative
source: ~/.claude/projects/<slug>/<session>.jsonl, one usage block per API call).

Usage:
  .\measure-session.ps1                # newest session of the fork project
  .\measure-session.ps1 -Last 3        # three newest (planned reps span sessions)
  .\measure-session.ps1 -ProjectDir <path-to ~\.claude\projects\...>

Caveat: subagent (sidechain) usage is included when it lands in the same transcript
file; cross-check one rep against /cost once to confirm nothing is undercounted.
#>
[CmdletBinding()]
param(
    [string]$RepoDir = '',
    [string]$ProjectDir = '',
    [int]$Last = 1
)
$ErrorActionPreference = 'Stop'

if (-not $ProjectDir) {
    $kitRoot = $PSScriptRoot
    if (-not $RepoDir) { $RepoDir = Join-Path (Split-Path $kitRoot -Parent) 'eShopOnWeb' }
    # Claude Code project slug: path with ':' and '\' replaced by '-'
    $slug = ([System.IO.Path]::GetFullPath($RepoDir)).Replace(':', '-').Replace('\', '-')
    $ProjectDir = Join-Path $HOME ".claude\projects\$slug"
}
if (-not (Test-Path $ProjectDir)) { Write-Host "FAIL: no transcript dir at $ProjectDir (pass -ProjectDir explicitly)" -ForegroundColor Red; exit 1 }

$files = Get-ChildItem (Join-Path $ProjectDir '*.jsonl') | Sort-Object LastWriteTime -Descending | Select-Object -First $Last
if (-not $files) { Write-Host "FAIL: no .jsonl transcripts in $ProjectDir" -ForegroundColor Red; exit 1 }

$grand = @{ input = 0; output = 0; cacheCreate = 0; cacheRead = 0; turns = 0 }
foreach ($f in $files) {
    $t = @{ input = 0; output = 0; cacheCreate = 0; cacheRead = 0; turns = 0 }
    $first = $null; $lastTs = $null
    foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
        if ($line -notmatch '"usage"') {
            # still track timestamps of non-usage entries for the session span
            if ($line -match '"timestamp":"([^"]+)"' -and -not $first) { $first = [datetime]$Matches[1] }
            continue
        }
        $e = $line | ConvertFrom-Json
        if ($e.timestamp) { if (-not $first) { $first = [datetime]$e.timestamp }; $lastTs = [datetime]$e.timestamp }
        $u = $e.message.usage
        if (-not $u) { continue }
        $t.turns++
        # missing properties yield $null, which casts to 0 (PS 5.1 compatible)
        $t.input       += [int64]$u.input_tokens
        $t.output      += [int64]$u.output_tokens
        $t.cacheCreate += [int64]$u.cache_creation_input_tokens
        $t.cacheRead   += [int64]$u.cache_read_input_tokens
    }
    $span = if ($first -and $lastTs) { ($lastTs - $first) } else { $null }
    [pscustomobject]@{
        session     = $f.BaseName.Substring(0, [Math]::Min(8, $f.BaseName.Length))
        started     = $first
        activeSpan  = if ($span) { '{0:hh\:mm\:ss}' -f $span } else { '?' }
        apiTurns    = $t.turns
        input       = $t.input
        output      = $t.output
        cacheCreate = $t.cacheCreate
        cacheRead   = $t.cacheRead
    } | Format-Table -AutoSize | Out-String | Write-Host
    foreach ($k in 'input','output','cacheCreate','cacheRead','turns') { $grand[$k] += $t[$k] }
}
if ($Last -gt 1) {
    Write-Host ("TOTAL over $($files.Count) sessions: input=$($grand.input) output=$($grand.output) cacheCreate=$($grand.cacheCreate) cacheRead=$($grand.cacheRead) apiTurns=$($grand.turns)")
}
