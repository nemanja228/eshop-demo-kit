# Run log

One row per rep. Push every rep branch to origin as you finish it (audit trail).
Per-rep artifacts (final diff, /context screenshot, cost readout, spec/tasklist copies,
notes) go in `runs/<branch-name>/`.

| date | cell | rep | branch | model ID(s) | duration | tokens | FAQ questions asked | outcome notes |
|------|------|-----|--------|-------------|----------|--------|---------------------|---------------|

## FAQ question log

| cell-rep | question (paraphrase) | answer given (FAQ entry or "your call") |
|----------|----------------------|------------------------------------------|

## Machine context disclosure

Record here, once per machine, what user-level context existed during scored runs
(~/.claude/CLAUDE.md present or moved aside, user-level hooks, permission mode used).

## Reset method (recorded by dryrun-1-3.ps1)

Reset method (between every scored rep), run from src\Web:
  dotnet ef database drop -f -c catalogcontext        -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
  dotnet ef database drop -f -c appidentitydbcontext  -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
(next app start recreates + reseeds both; verified 2026-08-03)
