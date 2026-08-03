# Plan, Delegate, Verify — talk plan (handoff document)

Consolidated design for the talk. Edit freely (inline opinions, cuts, reorders), then
start a fresh conversation with this file as the brief to build the actual deck and
speaker notes. Demo evidence (scoreboard numbers, screenshots) arrives after the matrix
runs; the deck can be built around labeled placeholders until then.

## 1. Identity

- **Title:** Plan, Delegate, Verify
- **Slot:** 60 min = ~45 min content + Q&A. Talk only; all demos pre-baked (screenshots,
  logs, diffs). Replay kit so attendees can try the exercise themselves.
- **Audience:** mixed-seniority engineers, after Nenad's two condensed workshops.
- **Position in the series:** feature-level craft, hands-on. Comes BEFORE [colleague]'s
  SDLC / rebirth-of-spec-driven-development talk (an order of magnitude up — do not claim
  that territory; tease it at the end). A third colleague covers the LLM-wiki topic.
  Likely the only demo-bearing talk.
- **Owns** (gaps Nenad left): planning deep-dive, subagents, hooks + agent-safety policy,
  MCP at pattern level, verification as the spine, team skills as proven practice.
- **Deliberately excluded:** skills versioning/ownership/distribution (no mature strategy
  to preach), the wiki, the big SDLC story.

## 2. Core themes

1. **Three acts = the loop:** Plan (slides 5-6), Delegate (7-8), Verify (9-11). The title
   is the structure.
2. **The experiment as evidence backbone:** one real task, same brief, run one-shot vs
   planned across models; scoreboard instead of assertions. Repo: pinned eShopOnWeb fork;
   task: product archiving. All fairness rules + traps documented in the kit
   (runbook.md, setup-report.md).
3. **Verification is the distinctive identity.** "It compiles" is not done; agents finish
   when they THINK they're done; a done-state makes it checkable. Gates ladder: compile
   (weak) → run locally (medium) → tests/acceptance criteria (strong) → independent
   review (strongest).
4. **The crown moved to the END** (was the opening thesis; punchier as the only
   reasonable explanation of the scoreboard everyone just saw): virtually all good
   engineering practices that were skipped for budget/discipline reasons are now close to
   required, because AI collapsed the feedback delay and acts like a very specific type
   of human.
5. **Process beats model** (the matrix punchline): a bigger model raises the ceiling of
   what fits in one attempt; it doesn't remove the need for the plan.

## 3. Timeline (45:00, 15 slides)

| # | Time | Slide | On screen | Say (essence) |
|---|------|-------|-----------|----------------|
| 1 | 0:00-2:00 | Cold open | Browser pair: feature "working" / archived item still on storefront. Caption: "Compiled. Demoed clean. Shipped broken." | No framing; straight into the hook. This talk is the loop that catches this class of failure. |
| 2 | 2:00-3:00 | Frame + sizing rule | The loop; banner "Non-trivial work only. One-line fixes stay one-line fixes." | Feature-level craft, hands-on; one real task three ways; the lifecycle-scale story is [colleague]'s talk. |
| 3 | 3:00-5:00 | The experiment | eShopOnWeb architecture diagram; the task; 3-run matrix; fairness footnote (same commit/prompt/CLAUDE.md, N reps, representative shown). | Public repo, replayable; task sounds trivial and isn't; matrix separates better-model from better-process. |
| 4 | 5:00-8:00 | One-shot runs | Giant diff stat; /context fill screenshot; "decided without asking" callout (basket). | Both one-shots produced something that runs. Explain the cache miss from the cold open. Tease full scoring later. |
| 5 | 8:00-12:00 | PLAN: the planning session | Plan-mode moments: clarifying questions asked; the cache decorator + third surface discovered before any code. | Deep-dive territory. What a planning session is, what the human does in it (answer questions, veto scope, decide the basket question), what it costs (minutes). Rule: every non-trivial feature starts here. |
| 6 | 12:00-15:00 | PLAN: the artifacts | spec.md + tasklist.md, three circles: surface map, decorator in file inventory, basket question surfaced for a human. | "The plan ASKED; the one-shot silently decided." Conversion slide — give it air. |
| 7 | 15:00-17:00 | DELEGATE: subagents | Diagram: main window clean, subagent does grubby investigation, only findings return. Real prompt example from the planning run. | Investigation pollutes context; delegate it, keep the conclusion. Pattern level, two minutes. |
| 8 | 17:00-21:00 | DELEGATE: chunks + model ladder | Tasklist mid-flight; one task's small diff vs the 900-line one-shot diff; spec-refinement diff after a mid-task discovery. Corner: ladder (Sonnet executes / Opus plans / Fable at codebase scope) + one-line cost logic. | One task, one clean session, cheap model. Plans are living documents. Planning is bounded, so the strong model there barely moves blended cost. Ambiguity mid-build = underspecified plan, not a model problem. |
| 9 | 21:00-25:00 | VERIFY: definition of done | "Agents finish when they THINK they're done." Gates ladder with what each catches. | War story: a batch of changes, all compiled clean, all deterministic runtime failures. Rule: paste the actual output, never "should work." |
| 10 | 25:00-29:00 | VERIFY: MCP as inputs & gates | Two columns: inputs (ticket via Jira) / gates (read-only DB — enforced at the SQL login, not by trusting a flag; browser; test runner). Beat: prefer a CLI when it does the same job (gh, playwright-cli) — cheaper in context. | Awareness level deliberately: MCP is how the agent sees your world and proves its work. Depth deferred to the later integrations session. |
| 11 | 29:00-33:00 | VERIFY: hooks + safety policy | "Allow most, gate the destructive." Ten-line real guard-hook excerpt (deny force-push / history rewrite). What we gate vs what flows. | The agent-safety topic Nenad deferred. Model judgment degrades as context grows; hooks don't. Pairing: verification proves the work is RIGHT; hooks guarantee a wrong step can't be CATASTROPHIC. Gate narrowly — friction kills adoption. |
| 12 | 33:00-37:00 | The scoreboard | Table: Sonnet one-shot / Opus one-shot / planned. Rows: surfaces, bugs, decisions surfaced-vs-silent, diff reviewability, tests, artifacts, tokens, wall-clock. Backup slide: D/E/F cells. | Walk rows, not cells. Opus column = punchline: better code, same process failures. Honest cost row: what the extra tokens bought. |
| 13 | 37:00-39:00 | Docs for free *(cuttable)* | spec.md beside the PR description — visibly the same text. | The lifecycle step everyone skips hardest is now a paste, not archaeology. |
| 14 | 39:00-41:30 | Team skills + buy-vs-build | jira + review-pr skills, one line + one output screenshot each, "proven in daily team use." Superpowers/spec-kit shape (spec→tasks→execute→verify) with highlighted assumption: green test suite as the self-correcting gate. | The libraries validate the shape; legacy lacks their gate, so: adopt the shape, own the gates. PIP in one sentence as the case study (no test suite, no prod-like safety net, manual deploys — the workflow IS the safety net). Present libraries as "what they assume" unless someone has run them. No versioning/ownership sermon. |
| 15 | 41:30-45:00 | THE CROWN + close | See §4. | See §4. |

Cut order if running long: 13 first, then shrink 7 to one minute.

## 4. The crown (slide 15 sequence)

1. **Four mechanisms** (the argument, one slide):
   - Speed collapsed the feedback delay — slow killers became same-afternoon killers.
   - The agent is an amnesiac literal reader — anything not written down doesn't exist;
     every session is a new hire.
   - It self-corrects only against machine-checkable gates — it can loop on a test or a
     build, not on "Marko knows how it should behave."
   - The codebase is the prompt — the agent amplifies whatever it reads; code-as-liability
     stops being a metaphor.
2. **The wall slide** — full practices list at once, unwalked; five seconds of silence;
   line: "you know which of these your projects skipped." The 17:
   local runnability + reliable fake data; tests, diamond-shaped (integration > unit on
   legacy — hill to die on); CI (over CD); surfaced errors / observability; specs +
   acceptance criteria; contracts between layers; comments about reasoning; UI/UX design
   docs; DB schema hygiene; reproducible dev setup; clear-over-clever / code as
   liability; DRY / KISS / domain design; conventions enforced by tooling; dead-code
   removal; code review; gating system boundaries; security.
3. **Two 30-second stories** (pick two): express-era prod-testing & fake data ("honestly
   not much slower for one careful human — an agent can't be that human"); reasoning
   comments via a landmine example (NOLOCK-is-safe-by-design / GETDATE-is-the-convention
   / frozen assembly name — "the only thing standing between the agent and helpfully
   'fixing' your deliberate weirdness").
4. **Economic beat:** the practices were skipped because they cost more than they
   returned short-term. AI squeezed that from both ends at once — cut the cost of doing
   them, collapsed the delay on the cost of skipping them. No economic case left;
   discipline and economics finally point the same way.
5. **The "specific type of human" rendering** (drafted, edit to taste): a brilliant,
   absurdly fast contractor with total amnesia and misplaced confidence. No memory
   between sessions → documentation becomes its working memory. Takes requirements
   literally → vague specs produce precisely what you said, not what you meant. Never
   gets bored or embarrassed → won't push back on a bad plan, so review gates are
   load-bearing. Works so fast that process debt surfaces the same afternoon, visibly,
   attributably.
6. **Big-org line, one breath** (placement open — crown vs bridge): "Big companies
   adopted every practice on this wall decades ago, not because they were more
   disciplined but because at their scale tribal knowledge dies: too many people, too
   much churn. AI just dropped that threshold to a team of five — every agent session is
   a new hire and the change rate is superhuman. The difference is we get the discipline
   without the bureaucracy, because this time the new hires write the documentation
   themselves."
7. **Closing line:** "Each of these was a slow killer. It's no longer slow, and it's no
   longer ignorable."
8. **Three asks:** next non-trivial ticket starts with a planning session; the done-state
   is written before the first line of code; the plan artifact ships with the PR. Plus
   the replay-kit link.
9. **Teaser handoff:** "[colleague] will take this from one feature to the entire
   lifecycle."

Timing risk: this is dense for 3:30. Either steal a minute from slide 14 or pre-decide
that mechanisms get 30 seconds as a build to the wall.

## 5. Anecdote bank (real, from prep — usable in 9/10/15)

- **Cold-cache false negative:** the cache-staleness trap "didn't reproduce" until the
  entry was warmed — the system looked correct under a lazy check. (Slide 9 or crown.)
- **Stale localStorage over the wrong-but-plausible file:** the admin kept showing an
  item that a spec edit had removed — two caches deep, verification protocol was the only
  thing separating "works" from "appeared to work."
- **The orphan process:** killing `dotnet.exe` left `Web.exe` alive holding ports and
  DLLs; the next build failed mysteriously. Cleanup that "ran fine" hadn't worked.
- **The cert callback:** a plausible one-line "fix" (PS 5.1 scriptblock cert callback)
  broke every request — the fix itself was the regression, caught only because the
  script was re-tested end to end.
- **Model drift discovery:** testing the migration script revealed every new migration
  scaffolds unrelated ALTER COLUMNs + a data-loss warning (2021 snapshot vs EF 8) — an
  unplanned scoring signal, found because the script was tested rather than shipped on
  faith.
- **Meta:** preparing this talk consisted of planning, delegating, and being repeatedly
  saved by verification. Say so.

## 6. Demo evidence — status & sources

- **Kit repo:** `nemanja228/eshop-demo-kit` (runbook, fairness rules, frozen prompts,
  pre-registered rubric, dry-run checklist, tested scripts, automation brief). Fork:
  `nemanja228/eShopOnWeb` @ `demo-base`.
- **Dry-run status at handoff:** 1.1 (cache) and 1.2 (shared-spec admin dead-end)
  reproduced by hand; 1.3 scripted and tested green; 1.4, the Sonnet throwaway, and the
  planned rep pending. Go/no-go (archiving vs sale-pricing escalation) decided by the
  throwaway per dryrun-checklist.md step 6.
- **Slide assets to harvest during runs** (re-staging later is expensive): stale/fresh
  storefront browser pair; admin-item-vanishes capture; giant one-shot diff stat;
  /context fill; spec+tasklist screenshots (three circles); spec-refinement diff;
  tasklist mid-flight; test output; scoreboard numbers per rep.
- **Work-side assets** (from the PIP machine): guard-hook excerpt (genericize), jira +
  review-pr output screenshots, the compiled-clean-failed-at-runtime war story.
- **Bitwarden contrast** (slide 10 spectrum): 20+ test projects = the ideal done-state;
  eShopOnWeb = partial; typical client legacy = none. "Our codebases live at the right
  end — that's why we substitute gates."

## 7. Open decisions (add your opinions here)

1. Scoreboard lead narrative: correctness failures vs construction-guaranteed process
   rows — decided by the dry-run evidence; both pre-designed.
2. Task: archiving vs sale-pricing escalation — dry-run step 6.
3. Big-org line: inside the crown vs spent as the bridge/teaser.
4. Crown stories: which two (see §5 candidates + your own).
5. The optional 60-second live moment (opening plan mode at slide 5): keep-if-ahead or
   cut outright.
6. Model naming on slides: generic tiers (recommended, slides don't rot) vs explicit
   names; say names verbally either way. Opus-vs-Fable-for-planning comparison exists as
   backup ammo if cell F runs.
7. Slide 13 (docs for free): keep or fold its one beat into the scoreboard.
8. Coordination: share the wall slide with [colleague] so his talk builds on it; confirm
   whether anyone else demos.

## 8. For the next conversation

Suggested kickoff: paste/attach this file and say what you want built first (deck
skeleton with placeholder assets vs full speaker notes per slide). The demo numbers slot
in after the matrix; everything else can be produced now. The kit repo is the source of
truth for demo mechanics — the deck conversation should not redesign the experiment.
