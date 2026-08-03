# Runbook — "Plan, Delegate, Verify" demo matrix

The operating manual for producing the talk's demo material. The kit repo holds this file,
the prompt pack, the rubric, and all run logs. The eShopOnWeb fork clone lives OUTSIDE the
kit tree (bootstrap.ps1 enforces this) because the kit contains the answer key and Claude
Code loads CLAUDE.md files from ancestor directories.

## The experiment

One task ("product archiving", brief frozen in prompts/task-brief.md) run several ways on
the identical starting state (tag `demo-base`):

| Cell | Mode | Model(s) | Reps |
|------|------|----------|------|
| A | one-shot | Sonnet | 3 |
| B | one-shot | Opus | 3 |
| C | plan → implement | Opus plans, Sonnet implements | 2-3 |
| D | plan → implement | Sonnet plans, Sonnet implements | 1-2 (backup slide) |
| E | plan → implement | Opus plans, Opus implements | 2 (execution-model control) |
| F | one-shot | Fable | 1-2 (Q&A ammo only, never the main scoreboard) |

The talk's scoreboard shows A, B, and C only. D/E/F live on one backup slide.

## Fairness rules (violating any of these invalidates the matrix)

1. Same starting commit (`demo-base`), same CLAUDE.md, same permission mode (acceptEdits),
   for every cell and rep.
2. Same task brief, verbatim, as the opening prompt of every cell.
3. Questions asked by ANY run are answered from prompts/faq-answers.md, verbatim. Never
   volunteer information; never answer beyond the FAQ entry.
4. No nudges, no retries. A run ends when the agent declares done.
5. Scoring only against the pre-registered rubric (prompts/rubric.md), frozen before the
   first scored run.
6. Record the exact model ID for every session (a scoreboard across mixed model snapshots
   is worthless).
7. Machine-level context: before scored runs, check `~/.claude/CLAUDE.md` (and any
   user-level instruction files). Either move them aside for the runs or record their
   content in runs/runs.md as a disclosed constant. Same treatment for user-level hooks.
8. Dry-run learnings may update the rubric and FAQ. They must NEVER update the task brief
   or the repo's CLAUDE.md (that would leak hints into the measured runs).

## Phases

- **Phase 0 — environment.** bootstrap.ps1 end-to-end green: toolchain, clone, pin, build,
  baseline tests recorded in setup-report.md. Apps verified running (Web, PublicApi,
  BlazorAdmin at /admin, admin login works).
- **Phase 1 — CLAUDE.md.** Authored under the strict content contract (see setup-report.md
  design notes; whitelist: snapshot, neutral project map, verified commands, DB mode,
  definition-of-done test gate; hard-exclude: any hint of caching, surfaces, baskets,
  features, tripwires). Committed, tagged `demo-base`, pushed. Then pin PinnedSha in
  bootstrap.ps1.
- **Phase 2 — prompt pack.** prompts/: task-brief.md, planning-instructions.md,
  implement-task-template.md, faq-answers.md, rubric.md. Frozen (commit) before phase 3
  ends.
- **Phase 3 — dry-run (non-scoring).** One exploratory planned run. Confirms: the shared-
  specification trap fires as designed, cache staleness reproduces, the task decomposes to
  ~5 slices, the basket question surfaces, migration friction is as expected. Decides:
  archiving vs sale-pricing escalation; whether correctness rows will differentiate or the
  construction-guaranteed rows lead the narrative.
- **Phase 4 — matrix.** Branch per rep: `cell-a-rep1`, `cell-b-rep2`, ... from `demo-base`.
  Fresh session per rep in the fork clone. One-shot cells can run headless
  (`claude -p @prompts/task-brief.md --model <id>` with JSON output for cost/duration
  capture); planned cells run interactively (plan session + one session per task).
  Capture per rep (into runs/<cell-rep>/): final diff (`git diff demo-base`), /context
  screenshot at end, cost/token readout, wall-clock, session artifacts (spec.md,
  tasklist.md for planned cells), notes. Log every rep in runs/runs.md: cell, rep, branch,
  model ID, duration, tokens, outcome notes.
- **Phase 5 — scoring + harvest.** Score all reps against rubric.md. Choose representative
  reps. Produce the scoreboard and shoot slide assets (incl. the admin-item-vanishes
  screen capture and the stale-storefront pair).
- **Phase 6 — replay kit.** Fork goes public with an attendee README + exercise. Spoiler
  handling: the exercise text lives in the fork; the kit (answer key) is shared after the
  talk or with a spoiler warning.

## Trap inventory (answer key — keep out of anything a run can read)

Ranked failure modes the rubric scores:
1. **Shared-specification trap**: CatalogFilterSpecification(+Paginated) is used by BOTH
   the storefront and the PublicApi list endpoint that BlazorAdmin consumes. Filtering
   archived items there hides them from the admin too → unarchive impossible via UI.
   Correct designs: includeArchived parameter or a separate specification.
2. **Storefront cache staleness**: CachedCatalogViewModelService, 30s SLIDING expiration,
   no invalidation, and admin writes happen in a different process (PublicApi) that cannot
   evict Web's in-process IMemoryCache. Correct handling is a surfaced design decision.
3. **Silent basket/checkout decision**: archived item already in a basket — block, remove,
   or honor? Must be surfaced, not silently decided. (FAQ has the canonical answer.)
4. **Migrations**: two DbContexts; documented commands in README (run from src/Web);
   both apps auto-migrate+seed on start; in-memory mode skips migrations.
5. **Test fragility**: PublicApiIntegrationTests are seed- and order-coupled (page of
   exactly 10; ids 1/5/12). New tests can collide. Existing spec unit tests must be
   updated coherently, not deleted/weakened.

Freebies the rubric also checks: past orders unaffected (orders snapshot catalog data —
comes free, but should be VERIFIED/stated); the vestigial server-rendered admin edit page;
health checks assert the ".NET Bot Black Sweatshirt" seed item (don't archive it in demos).

## Session hygiene

- One rep = one fresh branch + fresh session(s). /clear does not substitute for a fresh
  session between reps.
- Reset state between reps: `git checkout demo-base && git clean -fd`, then drop the two
  LocalDB databases (Microsoft.eShopOnWeb.CatalogDb, Microsoft.eShopOnWeb.Identity) so
  migrations and seeding replay from zero:
  `sqllocaldb stop mssqllocaldb; sqllocaldb start mssqllocaldb` then delete via
  `dotnet ef database drop` (per context) or SSMS/sqlcmd. Record the chosen method once in
  runs/runs.md and reuse it identically.
- Push every rep branch to the fork (origin) as you go; branches are the audit trail.
