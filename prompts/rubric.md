# Scoring rubric (pre-registered — frozen before the first scored run)

Every rep is scored on every dimension: **pass / partial / fail**, with a one-line note.
The representative rep per cell for the talk = the **median** C-score rep, never the best;
ties break toward fewer human interventions.

## C — correctness & completeness

- **C1 Storefront hides archived items** in the listing and under brand/type filters.
- **C2 Storefront freshness.** With the storefront under continuous traffic (repeated page
  hits), archive an item and measure when it disappears. Pass = promptly, or within a
  bounded window that the run deliberately chose AND documented. Partial = bounded but
  undocumented. Fail = unbounded staleness (the sliding-expiration behavior) or broken.
- **C3 Admin can still see archived items and unarchive them end-to-end via the UI.**
  Fail here is the dead-end bug (archived items unreachable) — flag it prominently.
- **C4 Basket/checkout behavior**: matches the FAQ answer if asked; if decided silently,
  is the chosen behavior coherent, implemented on both sides (basket display + checkout),
  and documented anywhere?
- **C5 Past orders unaffected** — stated and verified (test or demonstration), not assumed.
- **C6 Migration correctness**: CatalogContext migration adds the flag with a correct
  default; applies cleanly to an existing seeded LocalDB database; model snapshot updated;
  identity context untouched. Baseline noise (do NOT penalize): due to 2021-snapshot vs
  EF 8 model drift, every scaffolded migration carries unrelated ALTER COLUMN NOT NULL
  changes and a data-loss warning. A run that NOTICES and flags the unrelated changes
  earns a positive note; a run that hand-deletes them without understanding earns a
  negative one.
- **C7 API contract coherence**: the flag is handled consistently across list / get / 
  create / update DTOs. Specifically: does an admin edit (PUT) of an archived item
  silently unarchive it? (The update endpoint replaces fields wholesale.)
- **C8 Tests**: new behavior covered (storefront filtering, admin visibility/unarchive,
  checkout blocking); existing tests updated coherently — not deleted, not weakened (the
  API integration tests are seed- and order-coupled and WILL be affected); full suite
  green, actually run.

## P — process (construction-guaranteed differentiators)

- **P1 Decisions surfaced**: which product decisions (basket, admin visibility, freshness)
  were asked about vs silently taken? Count both.
- **P2 Artifacts**: does a spec/tasklist exist; does it match what was actually built; was
  it updated when something was discovered mid-implementation?
- **P3 Reviewability**: commits per logical unit; size of the largest single diff; could a
  reviewer reconstruct the reasoning from the branch alone?
- **P4 Definition-of-done honesty**: were build and full tests actually run, with results
  shown, and do the claims match reality?

## K — cost

- **K1** total tokens (all sessions of the rep). **K2** wall-clock. **K3** number of
  sessions and number of human interventions (FAQ answers given).

## Notes for scoring C2/C3 (how to reproduce)

- C2: keep hitting the storefront listing every ~10s while archiving via the admin (the
  cache uses 30s SLIDING expiration — continuous traffic never lets it expire unless the
  run changed that).
- C3: archive an item via admin UI, then attempt to locate and unarchive it using only the
  UI. Do not use the API or DB directly for the check. BEFORE judging, clear BlazorAdmin's
  client-side cache — `localStorage.removeItem('items')` in DevTools, or wait out its
  1-minute TTL — a stale admin list gives false verdicts in both directions.
- Never archive ".NET Bot Black Sweatshirt" during checks — the app's health checks assert
  it on the homepage.
