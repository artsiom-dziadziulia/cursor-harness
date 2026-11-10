---
name: aw-task
description: Start a new bug fix or feature through the project harness (ticket -> analysis -> plan -> user approval). Usage - /aw-task <Teamwork ID or URL> <ticket text or description>
disable-model-invocation: true
---

# /aw-task — start a task

You are the **orchestrator** defined in `docs/_harness/WORKFLOW.md`. Read it now (the root `AGENTS.md` is already in context).

## Steps
1. **Intake (S0).** From the user's message take: Teamwork ID (number from the URL `https://ravedigital.teamwork.com/app/tasks/<ID>`), title, ticket text, type (bug/feature), module(s).
   Missing ID, ticket text or module that you cannot infer ⇒ ask the user (one message, all questions) and stop.
2. Create `docs/tasks/<ID>-<kebab-slug>/` with `status.md` (from `docs/_harness/templates/status.md`), `00_intake.md` (from `templates/00_intake.md`) and an empty `journal.md`. Fill the current branch of each module repo via `git -C app/code/Aheadworks/<Module> branch --show-current`.
3. Decide standard vs **fast lane** (criteria in WORKFLOW.md) and record it in `status.md`.
4. **S1** — delegate to `aw-analyst` with: task folder, module(s), type, fast-lane flag. On blocking questions: stop and ask the user.
5. **S1R** — features only: delegate to `aw-spec-reviewer`; loop with `aw-analyst` rework at most 2 reviews (targeted re-review).
6. **S2/S2R** — delegate to `aw-planner` (not in fast lane), then `aw-plan-reviewer` (bugs and fast lane: it also reviews the analysis). At most 2 reviews.
7. After every step: one line in `status.md`, one line in `journal.md`. Keep `status.md` ≤ 60 lines.
8. **Gate A — stop.** Present to the user in Russian: problem/root cause in 2–3 sentences, the solution, task list, files/repos touched, risks, verification plan, and the path to `02_plan.md`. Ask for approval: "Ответьте `/aw-approve <ID>` или напишите правки к плану."

Pass each role only the exact files it needs; roles return ≤ 10 lines — do not ask them for more.
Never edit code in this command. Never use git write commands. Never trigger CI.
