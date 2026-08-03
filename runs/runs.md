# Run log

One row per rep. Push every rep branch to origin as you finish it (audit trail).
Per-rep artifacts (final diff, /context screenshot, cost readout, spec/tasklist copies,
notes) go in `runs/<branch-name>/`.

| date | cell | rep | branch | model ID(s) | duration | tokens | FAQ questions asked | outcome notes |
|------|------|-----|--------|-------------|----------|--------|---------------------|---------------|
| 2026-08-03 | a | 1 | cell-a-rep1 | claude-sonnet-5 | 27 minutes worked, actual session 90 minutes | api turns: 279  input: 558 output: 249725 cacheCreate: 1053931 cacheRead: 39224493 | Asked if archived display on admin handled via filter or show all products with marked archived status | Cache bugs continue to exist also with archiving, able to finish open checkout with an archived item (incorrect), correct behavior of orders (immutable), correct behavior on admin page of archive/unarchhive. |

## FAQ question log

| cell-rep | question (paraphrase) | answer given (FAQ entry or "your call") |
|----------|----------------------|------------------------------------------|
| a-1 | Q: Should admins see archived items in the admin list? | FAQ entry which was also recommended option |

## Machine context disclosure

Record here, once per machine, what user-level context existed during scored runs
(~/.claude/CLAUDE.md present or moved aside, user-level hooks, permission mode used).
None, renamed local claude.md to not interfere.

## Reset method (recorded by dryrun-1-3.ps1)

Reset method (between every scored rep), run from src\Web:
  dotnet ef database drop -f -c catalogcontext        -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
  dotnet ef database drop -f -c appidentitydbcontext  -p ..\Infrastructure\Infrastructure.csproj -s Web.csproj
(next app start recreates + reseeds both; verified 2026-08-03)
