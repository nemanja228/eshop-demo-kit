This is a PLANNING session only. The task is at the end of this message.

Rules:

1. Start in plan mode: explore the codebase and design the change. Make no edits while
   exploring.
2. If any product decision is ambiguous, ask me up to 5 clarifying questions before
   finalizing the plan.
3. When the plan is settled, write exactly two files in a new `plan/` folder at the repo
   root, then stop:
   - `plan/spec.md` — the approach; every file and surface the change touches and why;
     acceptance criteria, each checkable by a human or a test; decisions taken and their
     rationale; questions you asked and the answers you received.
   - `plan/tasklist.md` — small, independently buildable tasks in dependency order. Each
     task lists its scope (files), its own done-check, and which earlier tasks it depends
     on. Every task must be small enough to review as a standalone diff.
4. Commit the two files as the only change (message: "plan: product archiving").
5. Do NOT implement anything. Implementation happens in separate sessions.

The task (verbatim from task-brief.md):

---

Implement product archiving in this application.

Requirements:

- Administrators can archive and unarchive catalog items from the catalog admin UI.
- Archived items must no longer be visible to customers in the store.
- Existing orders must be unaffected.
- Include tests covering the new behavior.

When you consider the work complete, say so and summarize what you changed.
