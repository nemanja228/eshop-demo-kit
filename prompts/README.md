# Prompt pack (frozen)

The frozen inputs for every scored run. Freeze rule: after the first scored run, nothing
here changes. During phase 3 (dry-run) the FAQ and rubric MAY be amended; the task brief
may only be amended if the dry-run forces a task change (archiving → sale-pricing
escalation), which resets the matrix.

| File | Used by |
|------|---------|
| `task-brief.md` | Every cell, verbatim, as the opening prompt (one-shot cells: this is the whole prompt) |
| `planning-instructions.md` | Planned cells (C/D/E), session 1 — already embeds the brief verbatim |
| `implement-task-template.md` | Planned cells, one session per task (substitute {N}) |
| `faq-answers.md` | Operator: verbatim answers if (and only if) a run asks |
| `rubric.md` | Phase 5 scoring — pre-registered before any scored run |

Operator rules (see runbook.md Fairness): never volunteer information; answer questions
only from faq-answers.md, verbatim; log every question asked in runs/runs.md; no nudges,
no retries; a run ends when the agent declares done.
