# Automation brief — operator tooling (implement in fresh sessions on the run machine)

Two tools, one fresh Claude session each, started in THIS kit directory (never in the
fork). These are operator-side tools: they may read everything in the kit, but they are
bound by the constraints below. Paste the corresponding prompt as the session's first
message.

## Shared constraints (both sessions — the prompt text includes them)

1. Harness code lives in the kit root and is committed to the kit repo. Never in the fork.
2. Never modify tracked files in the fork. Any database change a tool makes for testing
   gets reverted or reset by the tool itself.
3. Tools wrap AROUND agent runs, never inside them: no injecting into sessions, no
   auto-answering agent questions. runbook.md "Fairness rules" are binding.
4. Reuse the proven patterns in dryrun-1-3.ps1 — the apphost orphan sweep
   (Get-EshopProcs), the Add-Type compiled cert delegate for PS 5.1 (a scriptblock
   ServerCertificateValidationCallback breaks ALL requests), the poll loop. These cost a
   day of debugging; do not reinvent them.
5. Windows PowerShell 5.1 compatible. Test end-to-end on this machine and show real
   output before committing. Commit to the kit and push.

---

## Prompt 1 — C2 cache-verification harness (verify-c2.ps1)

```
Read these files in this directory first: README.md, runbook.md, setup-report.md,
prompts/rubric.md (dimension C2), dryrun-1-3.ps1, automation-brief.md (shared
constraints — binding).

Build verify-c2.ps1 in this directory: an unattended harness that proves whether a
catalog change propagates to the storefront under continuous traffic, replacing the
manual 10-second-refresh test. The storefront caches its listing in-process with
30s SLIDING expiration (see setup-report.md), so the expected BASELINE behavior is:
stale indefinitely while polled, fresh after an idle gap.

Behavior:
1. Params: -RepoDir (default: sibling eShopOnWeb), -Label (default 'baseline'; artifacts
   go to runs/<Label>/), -StopApps (stop apps at the end), and the state predicates
   described in step 5.
2. Ensure Web and PublicApi are running (start them if not, one at a time, using the
   patterns from dryrun-1-3.ps1; sweep orphans first).
3. Warm phase: poll http://localhost:5000/ every 10s until the target product's current
   state is visible, minimum 3 hits (a cold cache entry produces a false negative —
   this is the whole point).
4. Fire the change. Default change: rename a first-page product (NOT ".NET Bot Black
   Sweatshirt" — health checks assert it) through PublicApi: POST api/authenticate as
   admin@microsoft.com / Pass@word1, GET api/catalog-items/{id}, PUT api/catalog-items
   with the modified name. Also accept -ChangeCommand (a scriptblock) that replaces the
   default — later reps will pass their own archive action here.
5. State detection must be two predicates over the storefront HTML, configurable:
   -OldState (regex that matches while the pre-change state is shown) and -NewState
   (regex for the post-change state) with an -ExpectAbsence switch for changes whose
   "new state" is an item disappearing (the archive case). Defaults derive from the
   rename (old name / new name).
6. Staleness phase: keep polling every 10s for 90s; log each poll with a timestamp and
   which state was observed. Verdict STALE-UNDER-TRAFFIC = old state still shown after
   >= 60s of continuous polling.
7. Freshness phase: stop polling for 40s, then poll once. Verdict FRESH-AFTER-IDLE =
   new state shown.
8. Output: timestamped log to console AND runs/<Label>/c2-log.txt, ending with the two
   verdicts. Exit 0 only if the observed behavior matches the expectation flags
   (-ExpectStale, default true for baseline).
9. Cleanup: revert the default rename via the same API; -ChangeCommand callers handle
   their own revert. Honor -StopApps.

Test it end-to-end on the baseline (default rename) and paste the real log: expected
result is STALE-UNDER-TRAFFIC=true, FRESH-AFTER-IDLE=true. Then commit to this repo
("verify-c2.ps1: unattended C2 cache harness, tested on baseline") and push.
```

---

## Prompt 2 — per-rep wrapper (rep.ps1)

```
Read these files in this directory first: README.md, runbook.md (Fairness rules and
phase 4 — binding), prompts/README.md, dryrun-1-3.ps1, automation-brief.md (shared
constraints — binding).

Build rep.ps1 in this directory: the operator's wrapper around one scored rep. It
automates everything AROUND a run and nothing inside it — it never launches, wraps, or
answers a Claude session; the operator runs the session by hand between 'start' and
'finish'.

Embed the cell matrix from runbook.md (cell -> mode, model, prompt file, planned reps)
so the tool knows what to print per cell.

rep.ps1 start -Cell <a|b|c|d|e|f> -Rep <n>:
1. Guards: fork working tree clean; no app processes (orphan sweep from dryrun-1-3.ps1);
   warn if ~/.claude/projects/<fork-slug>/memory exists (verify how this machine slugs
   the fork path rather than guessing) and offer to delete it (fairness rule 9).
2. git fetch, create branch cell-<cell>-rep<n> from demo-base, check it out.
3. Create runs/cell-<cell>-rep<n>/ here in the kit, write start timestamp + cell + model
   into meta.json.
4. Print the operator's launch card: which model to select, which prompt file to paste
   verbatim (prompts/task-brief.md for one-shots, prompts/planning-instructions.md for
   planned session 1), permission mode (acceptEdits), and the reminders: FAQ-only
   answers (log every question), no nudges, capture /context screenshot + cost readout
   at the end.

rep.ps1 finish -Cell <a> -Rep <n>:
1. Capture into runs/cell-<cell>-rep<n>/: git diff demo-base (full patch + --stat), the
   list of commits, and for planned cells a copy of plan/spec.md and plan/tasklist.md if
   present.
2. Interactively prompt (Read-Host) for: tokens/cost readout, FAQ questions asked (or
   none), one-line outcome note. Compute duration from meta.json.
3. Append the completed row to runs/runs.md (table schema already in that file).
4. Push the rep branch to origin.
5. Reset for the next rep: check out demo-base (detached), run the DB reset (the two
   dotnet ef database drop -f commands from README.md), delete the fork project's
   auto-memory directory if it reappeared, and verify no app processes survive.

Test both subcommands end-to-end with a throwaway rep (cell x, rep 0): start, make a
trivial commit on the branch, finish (enter dummy readouts), verify the runs.md row and
runs/cell-x-rep0/ artifacts, then delete the branch locally and on origin and remove the
dummy row/artifacts. Paste the real transcript of that test. Then commit ("rep.ps1:
per-rep wrapper, dry-tested") and push.
```
