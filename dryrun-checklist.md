# Phase 3 — dry-run procedure (exact)

Purpose: de-risk the scored matrix. Everything here is UNSCORED. Run on the machine that
will run the matrix (timing/token calibration must come from that machine).

Ground rules: dry-run learnings may amend `prompts/faq-answers.md` and `prompts/rubric.md`
only. The task brief, CLAUDE.md, and `demo-base` never change (sole exception: the task
swap in step 6, which resets the whole matrix). Dry-run branches are never merged and
never scored.

## Step 0 — machine context (5 min)

- Check `~/.claude/CLAUDE.md` and user-level hooks on this machine. Move aside or record
  verbatim in `runs/runs.md` → "Machine context disclosure". Decide once; applies to all
  scored runs.
- Confirm Claude Code is on the intended account; note plan/limits.
- `bootstrap.ps1` exit 0.

## Step 1 — manual trap verification, no agents, no feature (20 min)

On a throwaway branch `dryrun-manual` from `demo-base`:

1. **Cache staleness repro.** Start Web, then PublicApi. Open the storefront and refresh
   it every ~10s continuously. In `/admin`, rename any product EXCEPT ".NET Bot Black
   Sweatshirt" (health checks assert it). Expected: the storefront keeps showing the old
   name for well over 30s while you keep refreshing (sliding expiration renews the entry);
   stop refreshing for ~35s and the new name appears. Record actual observed behavior —
   this calibrates rubric C2's reproduction protocol.
2. **Shared-spec trap repro.** Hand-edit `CatalogFilterSpecification` to exclude one item
   id (e.g. `.Where(i => i.Id != 5)`). Run both apps. Expected: the item vanishes from the
   storefront AND from the BlazorAdmin list (same spec via the same API endpoint) — the
   admin dead-end is real. Revert the edit (never commit it).
3. **Migration mechanics + DB reset rehearsal.** Run the README's
   `dotnet ef migrations add DryRunProbe ...` (catalog context), `database update`, then
   remove/downgrade. Then rehearse the full reset: drop both databases
   (`dotnet ef database drop` per context, or your chosen method), re-run apps, confirm
   auto-migrate + re-seed. Record the chosen reset method in `runs/runs.md` — it will be
   used identically between all scored reps.
4. **Measurement rehearsal.** Confirm where tokens/cost/duration are read in this
   environment (e.g. `/cost`, `/context`), take one screenshot, create the
   `runs/<branch>/` folder pattern.

Delete `dryrun-manual` afterwards.

## Step 2 — throwaway one-shot, Sonnet (1 session)

Branch `dryrun-oneshot-sonnet` from `demo-base`. Fresh session, acceptEdits, interactive,
`prompts/task-brief.md` verbatim as the whole prompt. Operate exactly per the fairness
rules (FAQ-only answers, no nudges, ends when it declares done).

Watch for: which surfaces it touches; whether it handles or misses the cache; whether it
asks anything (log FAQ gaps); whether its "done" claim matches reality. Afterwards, score
it informally against the full rubric — this is also the scoring-protocol rehearsal.

## Step 3 — throwaway planned rep (plan session + at least 2 task sessions)

Branch `dryrun-planned` from `demo-base`. Fresh session, Opus,
`prompts/planning-instructions.md` verbatim.

Validate the planning session: does it ask the basket question (FAQ rehearsal)? Does the
spec's surface map include all three heads, the cache decorator, and the migration? Is the
tasklist ~5 tasks, each with a done-check, dependency-ordered? Does the plan-mode →
write `plan/` → single-commit flow work mechanically?

Then run at least two task sessions with `prompts/implement-task-template.md` (validate:
reads plan/, stays in scope, updates tasklist, per-task commit, runs build+tests).
Completing all tasks is optional but recommended once: it yields the first full timing and
token calibration for a planned rep.

## Step 4 — record

Write `dryrun-report.md` (kit root): observations per step, timings, tokens, FAQ gaps
found, rubric problems found, informal one-shot scores.

## Step 5 — amend and freeze

Apply any FAQ/rubric amendments, commit as "phase 3 close: FAQ+rubric frozen". After this
commit they do not change.

## Step 6 — go / no-go decision

- **Escalate to sale-pricing ONLY IF** the Sonnet one-shot cleanly passed C1 + C2 + C3
  (storefront hiding, freshness handled/documented, admin unarchive intact). Escalation
  means: new brief, new recon pass, matrix reset — a deliberate, expensive choice.
- Otherwise: **GO.** Reset the DB, delete or archive dry-run branches (never merge), and
  begin phase 4 with cell A rep 1.
- Also decide here, based on the one-shot's informal scores: whether the talk's scoreboard
  narrative leads with correctness failures or with the construction-guaranteed rows
  (decisions surfaced, reviewability, artifacts). Both are pre-designed; pick the one the
  evidence supports.
